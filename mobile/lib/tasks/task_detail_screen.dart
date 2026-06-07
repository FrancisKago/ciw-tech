import 'package:flutter/material.dart';
import '../models/task.dart';
import 'tasks_list_screen.dart' show statusLabel;

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key, required this.task, required this.onStart, required this.onClose,
  });
  final Task task;
  final VoidCallback onStart; // assigned → in_progress
  final VoidCallback onClose; // ouvre le formulaire rapport

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      // Contenu défilant : une longue description ne masque jamais l'action.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Statut : ${statusLabel(task.status)}'),
          const SizedBox(height: 8),
          Text('Priorité : ${task.priority.name}'),
          const SizedBox(height: 16),
          Text(task.description),
        ]),
      ),
      // Action dans une barre fixe : toujours visible, jamais rognée.
      bottomNavigationBar: _actionBar(),
    );
  }

  Widget? _actionBar() {
    final Widget? button = switch (task.status) {
      TaskStatus.assigned => ElevatedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow), label: const Text('Démarrer')),
      TaskStatus.inProgress => ElevatedButton.icon(
          onPressed: onClose,
          icon: const Icon(Icons.check), label: const Text('Clôturer')),
      TaskStatus.done => null,
      TaskStatus.approved => null,
    };
    if (button == null) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, height: 48, child: button),
      ),
    );
  }
}
