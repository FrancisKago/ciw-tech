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
    this.onPunchCreated, this.onSignOut,
  });
  final String userId;
  final GeoService geo;
  final PhotoService photo;
  final PunchRepository repo;
  final int pendingCount;

  /// Appelé après un pointage réussi pour déclencher la synchro immédiate.
  final Future<void> Function()? onPunchCreated;

  /// Déconnexion (Firebase + Clerk).
  final Future<void> Function()? onSignOut;

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
      await widget.onPunchCreated?.call(); // synchro immédiate de la photo
      if (mounted) setState(() => _message = 'Pointage enregistré ✓');
    } on GeoDenied {
      setState(() => _message = 'Activez la localisation pour pointer.');
    } on PhotoCancelled {
      setState(() => _message = 'Une photo est obligatoire pour pointer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez vous reconnecter pour pointer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (ok == true) await widget.onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pointage'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SyncBadge(pendingCount: widget.pendingCount)),
          ),
          if (widget.onSignOut != null)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout),
              onPressed: _busy ? null : _confirmSignOut,
            ),
        ],
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
