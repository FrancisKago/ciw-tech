import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/tasks/task_create_screen.dart';

void main() {
  final sites = const [(id: 's1', name: 'Site A')];
  final techs = const [(id: 'tech_1', name: 'Awono')];

  testWidgets('soumet une tâche valide', (tester) async {
    Map<String, dynamic>? sent;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: true,
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt) async {
          sent = {
            'title': title, 'siteId': siteId, 'assigneeId': assigneeId,
            'priority': priority,
          };
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('task_title')), 'Réparer');
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();

    expect(sent!['title'], 'Réparer');
    expect(sent!['siteId'], 's1');         // 1er site pré-sélectionné
    expect(sent!['assigneeId'], 'tech_1'); // 1er technicien pré-sélectionné
    expect(sent!['priority'], TaskPriority.normal);
  });

  testWidgets('hors-ligne : soumission bloquée avec message', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: false,
        onCreate: (a, b, c, d, e, f) async { called = true; },
      ),
    ));
    await tester.enterText(find.byKey(const Key('task_title')), 'X');
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();
    expect(called, false);
    expect(find.textContaining('en ligne'), findsOneWidget);
  });

  testWidgets('listes vides : messages explicites + bouton Créer désactivé', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: const [], technicians: const [], isOnline: true,
        onCreate: (a, b, c, d, e, f) async {},
      ),
    ));
    expect(find.textContaining('Aucun site'), findsOneWidget);
    expect(find.textContaining('Aucun technicien'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byKey(const Key('create_submit')));
    expect(btn.onPressed, isNull); // bouton désactivé tant que les listes sont vides
  });
}
