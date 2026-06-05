import 'package:flutter/material.dart';
import '../models/punch.dart';
import '../pointage/geo_service.dart';
import '../pointage/photo_service.dart';
import '../pointage/punch_repository.dart';
import '../widgets/sync_badge.dart';

class PointageScreen extends StatefulWidget {
  const PointageScreen({
    super.key, required this.userId, required this.geo, required this.photo,
    required this.repo, required this.pendingCount,
  });
  final String userId;
  final GeoService geo;
  final PhotoService photo;
  final PunchRepository repo;
  final int pendingCount;

  @override
  State<PointageScreen> createState() => _PointageScreenState();
}

class _PointageScreenState extends State<PointageScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _punch(PunchKind kind) async {
    setState(() { _busy = true; _message = null; });
    try {
      final fix = await widget.geo.currentFix();       // bloque si GPS refusé
      final photoPath = await widget.photo.capture();  // bloque si pas de photo
      await widget.repo.createPunch(
        userId: widget.userId, kind: kind,
        lat: fix.lat, lng: fix.lng, accuracy: fix.accuracy,
        siteId: null, photoPath: photoPath,
      );
      setState(() => _message = 'Pointage enregistré ✓');
    } on GeoDenied {
      setState(() => _message = 'Activez la localisation pour pointer.');
    } on PhotoCancelled {
      setState(() => _message = 'Une photo est obligatoire pour pointer.');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pointage'),
        actions: [Padding(padding: const EdgeInsets.all(8), child: SyncBadge(pendingCount: widget.pendingCount))],
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _punch(PunchKind.checkIn),
            icon: const Icon(Icons.login), label: const Text('Arrivée'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _punch(PunchKind.checkOut),
            icon: const Icon(Icons.logout), label: const Text('Départ'),
          ),
          const SizedBox(height: 24),
          if (_busy) const CircularProgressIndicator(),
          if (_message != null) Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        ]),
      ),
    );
  }
}
