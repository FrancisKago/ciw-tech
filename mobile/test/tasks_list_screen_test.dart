import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/tasks/tasks_list_screen.dart';

Task _task(String id, String title, TaskStatus s) => Task(
      id: id, title: title, description: '', siteId: 's1',
      assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.normal,
      dueAt: null, status: s, report: null,
    );

void main() {
  testWidgets('affiche le titre et le statut de chaque tâche', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TasksListScreen(
        title: 'Mes tâches',
        tasks: Stream.value([_task('t1', 'Réparer', TaskStatus.assigned)]),
        onTapTask: (_) {},
      ),
    ));
    await tester.pump();
    expect(find.text('Réparer'), findsOneWidget);
    expect(find.textContaining('assigné'), findsOneWidget);
  });

  testWidgets('affiche le bouton Créer si onCreate fourni', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TasksListScreen(
        title: 'Tâches créées',
        tasks: Stream.value(const []),
        onTapTask: (_) {},
        onCreate: () {},
      ),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
