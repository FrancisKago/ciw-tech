import 'package:flutter/material.dart';
import '../models/task.dart';

String statusLabel(TaskStatus s) => switch (s) {
      TaskStatus.assigned => 'assigné',
      TaskStatus.inProgress => 'en cours',
      TaskStatus.done => 'terminé',
    };

class TasksListScreen extends StatelessWidget {
  const TasksListScreen({
    super.key, required this.title, required this.tasks, required this.onTapTask,
    this.onCreate,
  });
  final String title;
  final Stream<List<Task>> tasks;
  final void Function(Task) onTapTask;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
