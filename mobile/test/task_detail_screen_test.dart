import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/tasks/task_detail_screen.dart';

Task _task(TaskStatus s) => Task(
      id: 't1', title: 'Réparer', description: 'détail', siteId: 's1',
      assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.normal,
      dueAt: null, status: s, report: null,
    );

void main() {
  testWidgets('statut assigned : bouton Démarrer visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskDetailScreen(task: _task(TaskStatus.assigned),
          onStart: () {}, onClose: () {}),
    ));
    expect(find.text('Démarrer'), findsOneWidget);
    expect(find.text('Clôturer'), findsNothing);
  });

  testWidgets('statut in_progress : bouton Clôturer visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskDetailScreen(task: _task(TaskStatus.inProgress),
          onStart: () {}, onClose: () {}),
    ));
    expect(find.text('Clôturer'), findsOneWidget);
    expect(find.text('Démarrer'), findsNothing);
  });

  testWidgets('statut done : aucune action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskDetailScreen(task: _task(TaskStatus.done),
          onStart: () {}, onClose: () {}),
    ));
    expect(find.text('Démarrer'), findsNothing);
    expect(find.text('Clôturer'), findsNothing);
  });
}
