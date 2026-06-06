import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'auth/firebase_auth_gate.dart';
import 'core/firebase_bootstrap.dart';
import 'outbox/outbox_db.dart';
import 'outbox/outbox_uploader.dart';
import 'outbox/sync_controller.dart';
import 'pointage/punch_repository.dart';

/// Clé publiable Clerk, fournie au lancement :
/// `flutter run --dart-define=CLERK_PUBLISHABLE_KEY=pk_...`
const clerkPublishableKey = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();
  final fs = FirebaseFirestore.instance;
  fs.settings = const Settings(persistenceEnabled: true); // cache offline
  final outbox = OutboxDb.open();
  final uploader = OutboxUploader(fs, outbox);
  SyncController(
    onlineStream: Connectivity().onConnectivityChanged
        .map((r) => !r.contains(ConnectivityResult.none)),
    drain: uploader.drainOnce,
  ).start();

  runApp(ProviderScope(child: PointageApp(
    outbox: outbox, repo: PunchRepository(fs, outbox),
  )));
}

class PointageApp extends StatelessWidget {
  const PointageApp({super.key, required this.outbox, required this.repo});
  final OutboxDb outbox;
  final PunchRepository repo;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);

    // Pas de clé Clerk fournie : on affiche un écran d'aide explicite.
    if (clerkPublishableKey.isEmpty) {
      return MaterialApp(
        title: 'Cameroon Innovation',
        theme: theme,
        home: const _MissingKeyScreen(),
      );
    }

    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: clerkPublishableKey),
      child: MaterialApp(
        title: 'Cameroon Innovation',
        theme: theme,
        home: ClerkAuthBuilder(
          signedInBuilder: (context, authState) => FirebaseAuthGate(
            clerkAuthState: authState,
            repo: repo,
            pendingCountStream: outbox.pendingCountStream(),
          ),
          signedOutBuilder: (context, authState) => const Scaffold(
            body: SafeArea(child: ClerkAuthentication()),
          ),
        ),
      ),
    );
  }
}

class _MissingKeyScreen extends StatelessWidget {
  const _MissingKeyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.key_off, size: 48),
              SizedBox(height: 16),
              Text(
                'Clé publiable Clerk manquante.\n\n'
                'Relancez avec :\n'
                'flutter run --dart-define=CLERK_PUBLISHABLE_KEY=pk_...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
