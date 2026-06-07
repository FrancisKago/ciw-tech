import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../pointage/geo_service.dart';
import '../pointage/photo_service.dart';
import '../pointage/punch_repository.dart';
import '../pointage/pointage_screen.dart';
import '../tasks/task_repository.dart';
import '../notifications/fcm_service.dart';
import '../tasks/home_shell.dart';
import '../tasks/tasks_list_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_report_screen.dart';
import '../tasks/task_create_screen.dart';
import 'clerk_flutter_auth_service.dart';
import 'firebase_bridge.dart';

/// Une fois Clerk connecté, assure la connexion Firebase (échange du JWT Clerk
/// contre un jeton personnalisé via la Cloud Function `mintFirebaseToken`) puis
/// affiche [HomeShell] avec les onglets selon le rôle.
class FirebaseAuthGate extends StatefulWidget {
  const FirebaseAuthGate({
    super.key,
    required this.clerkAuthState,
    required this.repo,
    required this.pendingCountStream,
    required this.onSyncNow,
    required this.taskRepo,
    required this.fcm,
  });

  final ClerkAuthState clerkAuthState;
  final PunchRepository repo;
  final Stream<int> pendingCountStream;
  final TaskRepository taskRepo;
  final FcmService fcm;

  /// Déclenche une vidange immédiate de l'outbox (upload des photos).
  final Future<void> Function() onSyncNow;

  @override
  State<FirebaseAuthGate> createState() => _FirebaseAuthGateState();
}

class _FirebaseAuthGateState extends State<FirebaseAuthGate> {
  bool _started = false;
  Object? _error;
  bool _fcmStarted = false;

  @override
  void initState() {
    super.initState();
    _ensureFirebaseSignIn();
  }

  Future<void> _ensureFirebaseSignIn() async {
    if (_started) return;
    _started = true;
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      final bridge = FirebaseBridge(
        ClerkFlutterAuthService(widget.clerkAuthState),
        FirebaseFunctions.instance,
        FirebaseAuth.instance,
      );
      await bridge.signInToFirebase();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _started = false;
    });
    _ensureFirebaseSignIn();
  }

  /// Déconnexion complète : Firebase d'abord (pour forcer un nouveau pont au
  /// prochain login), puis Clerk (ce qui ramène à l'écran de connexion).
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await widget.clerkAuthState.signOut();
  }

  Future<String> _role(User user) async {
    final res = await user.getIdTokenResult();
    return (res.claims?['role'] as String?) ?? 'technician';
  }

  void _openTask(BuildContext context, Task t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TaskDetailScreen(
        task: t,
        onStart: () => widget.taskRepo.startTask(t.id),
        onClose: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaskReportScreen(
              pickPhoto: () async {
                try {
                  return await PhotoService().capture();
                } on PhotoCancelled {
                  return null;
                }
              },
              onSubmit: (text, minutes, photos) async {
                await widget.taskRepo.submitReport(
                    taskId: t.id, text: text, minutesSpent: minutes, photoPaths: photos);
                await widget.onSyncNow();
              },
            ),
          ));
        },
      ),
    ));
  }

  void _openCreate(BuildContext context, String uid, FirebaseFirestore fs) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StreamBuilder<List<ConnectivityResult>>(
        stream: Connectivity().onConnectivityChanged,
        initialData: const [ConnectivityResult.wifi],
        builder: (context, connSnap) {
          final online = !(connSnap.data ?? const [ConnectivityResult.none])
              .contains(ConnectivityResult.none);
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: fs.collection('sites').snapshots(),
            builder: (context, sitesSnap) {
              final sites = (sitesSnap.data?.docs ?? [])
                  .map((d) => (id: d.id, name: (d.data()['name'] ?? d.id) as String))
                  .toList();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: fs.collection('users').where('role', isEqualTo: 'technician').snapshots(),
                builder: (context, usersSnap) {
                  final techs = (usersSnap.data?.docs ?? [])
                      .map((d) => (id: d.id, name: (d.data()['name'] ?? d.id) as String))
                      .toList();
                  return TaskCreateScreen(
                    sites: sites,
                    technicians: techs,
                    isOnline: online,
                    onCreate: (title, desc, siteId, assigneeId, priority, dueAt) =>
                        widget.taskRepo.createTask(
                            title: title,
                            description: desc,
                            siteId: siteId,
                            assigneeId: assigneeId,
                            createdBy: uid,
                            priority: priority,
                            dueAt: dueAt),
                  );
                },
              );
            },
          );
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Connexion Firebase impossible.\n$_error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connexion…'),
                ],
              ),
            ),
          );
        }
        return FutureBuilder<String>(
          future: _role(user),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = roleSnap.data!;
            if (!_fcmStarted) {
              _fcmStarted = true;
              widget.fcm.start(user.uid);
            }
            final fs = FirebaseFirestore.instance;
            return HomeShell(
              role: role,
              userId: user.uid,
              pointageTab: StreamBuilder<List<Task>>(
                stream: widget.taskRepo.tasksForAssignee(user.uid),
                builder: (context, tasksSnap) {
                  final active = (tasksSnap.data ?? const <Task>[])
                      .where((t) => t.status == TaskStatus.inProgress)
                      .map((t) => (taskId: t.id, siteId: t.siteId, title: t.title))
                      .toList();
                  return StreamBuilder<int>(
                    stream: widget.pendingCountStream,
                    initialData: 0,
                    builder: (context, pendingSnap) => PointageScreen(
                      userId: user.uid,
                      geo: GeoService(),
                      photo: PhotoService(),
                      repo: widget.repo,
                      pendingCount: pendingSnap.data ?? 0,
                      onPunchCreated: widget.onSyncNow,
                      onSignOut: _signOut,
                      activeTasks: active,
                    ),
                  );
                },
              ),
              myTasksTab: TasksListScreen(
                title: 'Mes tâches',
                tasks: widget.taskRepo.tasksForAssignee(user.uid),
                onTapTask: (t) => _openTask(context, t),
              ),
              managerTasksTab: TasksListScreen(
                title: 'Tâches créées',
                tasks: widget.taskRepo.tasksCreatedBy(user.uid),
                onTapTask: (t) => _openTask(context, t),
                onCreate: () => _openCreate(context, user.uid, fs),
              ),
            );
          },
        );
      },
    );
  }
}
