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
    this.activeTasks = const [],
  });
  final String userId;
  final GeoService geo;
  final PhotoService photo;
  final PunchRepository repo;
  final int pendingCount;
  final List<({String taskId, String siteId, String title})> activeTasks;

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
  String? _selectedTaskId;
  String? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    if (widget.activeTasks.length == 1) {
      _selectedTaskId = widget.activeTasks.first.taskId;
      _selectedSiteId = widget.activeTasks.first.siteId;
    }
  }

  Future<void> _punch(PunchKind kind) async {
    setState(() { _busy = true; _message = null; });
    try {
      final fix = await widget.geo.currentFix();       // bloque si GPS refusé
      final photoPath = await widget.photo.capture();  // bloque si pas de photo
      await widget.repo.createPunch(
        userId: widget.userId, kind: kind,
        lat: fix.lat, lng: fix.lng, accuracy: fix.accuracy,
        siteId: _selectedSiteId, photoPath: photoPath,
        taskId: _selectedTaskId,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/logo_mark_1024.png', height: 28),
            const SizedBox(width: 8),
            const Text('Cameroon Innovation'),
          ],
        ),
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
          if (widget.activeTasks.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: DropdownButton<String>(
                key: const Key('task_picker'),
                isExpanded: true,
                hint: const Text('Sélectionner une tâche'),
                value: _selectedTaskId,
                items: widget.activeTasks.map((t) => DropdownMenuItem(
                  value: t.taskId,
                  child: Text(t.title),
                )).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final task = widget.activeTasks.firstWhere((t) => t.taskId == value);
                  setState(() {
                    _selectedTaskId = task.taskId;
                    _selectedSiteId = task.siteId;
                  });
                },
              ),
            ),
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
