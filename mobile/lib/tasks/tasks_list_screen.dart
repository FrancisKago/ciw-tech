import 'package:flutter/material.dart';
import '../models/task.dart';

String statusLabel(TaskStatus s) => switch (s) {
      TaskStatus.assigned => 'assigné',
      TaskStatus.inProgress => 'en cours',
      TaskStatus.done => 'terminé',
      TaskStatus.approved => 'validé',
    };

class TasksListScreen extends StatelessWidget {
  const TasksListScreen({
    super.key, required this.title, required this.tasks, required this.onTapTask,
    this.onCreate, this.onSignOut,
  });
  final String title;
  final Stream<List<Task>> tasks;
  final void Function(Task) onTapTask;
  final VoidCallback? onCreate;

  /// Déconnexion (Firebase + Clerk). Si fourni, affiche un bouton dans l'AppBar.
  final Future<void> Function()? onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez vous reconnecter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (ok == true) await onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmSignOut(context),
            ),
        ],
      ),
      floatingActionButton: onCreate == null
          ? null
          : FloatingActionButton(onPressed: onCreate, child: const Icon(Icons.add)),
      body: StreamBuilder<List<Task>>(
        stream: tasks,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Aucune tâche.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return ListTile(
                title: Text(t.title),
                subtitle: Text('${statusLabel(t.status)} · ${t.priority.name}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTapTask(t),
              );
            },
          );
        },
      ),
    );
  }
}
