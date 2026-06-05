import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/firebase_bootstrap.dart';
import 'outbox/outbox_db.dart';
import 'outbox/outbox_uploader.dart';
import 'outbox/sync_controller.dart';
import 'pointage/geo_service.dart';
import 'pointage/photo_service.dart';
import 'pointage/punch_repository.dart';
import 'pointage/pointage_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();
  final fs = FirebaseFirestore.instance;
  fs.settings = const Settings(persistenceEnabled: true); // cache offline
  final outbox = OutboxDb.open();
  final uploader = OutboxUploader(fs, outbox);
  final sync = SyncController(
    onlineStream: Connectivity().onConnectivityChanged
        .map((r) => !r.contains(ConnectivityResult.none)),
    drain: uploader.drainOnce,
  )..start();

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
    return MaterialApp(
      title: 'Cameroon Innovation',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: StreamBuilder<int>(
        stream: outbox.pendingCountStream(),
        initialData: 0,
        builder: (context, snap) => PointageScreen(
          userId: 'TODO-from-auth', // remplacé par l'uid Firebase une fois 0.9 intégré
          geo: GeoService(), photo: PhotoService(), repo: repo,
          pendingCount: snap.data ?? 0,
        ),
      ),
    );
  }
}
