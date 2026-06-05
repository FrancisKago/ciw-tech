import 'package:flutter/material.dart';

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) {
      return const Chip(avatar: Icon(Icons.cloud_done, size: 18), label: Text('À jour'));
    }
    return Chip(
      avatar: const Icon(Icons.cloud_upload, size: 18),
      label: Text('$pendingCount non synchronisé(s)'),
    );
  }
}
