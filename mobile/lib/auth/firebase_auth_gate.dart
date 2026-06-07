import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pointage/geo_service.dart';
import '../pointage/photo_service.dart';
import '../pointage/punch_repository.dart';
import '../pointage/pointage_screen.dart';
import 'clerk_flutter_auth_service.dart';
import 'firebase_bridge.dart';

/// Une fois Clerk connecté, assure la connexion Firebase (échange du JWT Clerk
/// contre un jeton personnalisé via la Cloud Function `mintFirebaseToken`) puis
/// affiche [PointageScreen] avec l'uid Firebase réel.
class FirebaseAuthGate extends StatefulWidget {
  const FirebaseAuthGate({
    super.key,
    required this.clerkAuthState,
    required this.repo,
    required this.pendingCountStream,
    required this.onSyncNow,
  });

  final ClerkAuthState clerkAuthState;
  final PunchRepository repo;
  final Stream<int> pendingCountStream;

  /// Déclenche une vidange immédiate de l'outbox (upload des photos).
  final Future<void> Function() onSyncNow;

  @override
  State<FirebaseAuthGate> createState() => _FirebaseAuthGateState();
}

class _FirebaseAuthGateState extends State<FirebaseAuthGate> {
  bool _started = false;
  Object? _error;

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
          ),
        );
      },
    );
  }
}
