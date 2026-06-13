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
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt,
            {required DomaineTrade domaine}) async {
          sent = {
            'title': title, 'siteId': siteId, 'assigneeId': assigneeId,
            'priority': priority, 'domaine': domaine,
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
        onCreate: (a, b, c, d, e, f, {required DomaineTrade domaine}) async { called = true; },
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
        onCreate: (a, b, c, d, e, f, {required DomaineTrade domaine}) async {},
      ),
    ));
    expect(find.textContaining('Aucun site'), findsOneWidget);
    expect(find.textContaining('Aucun technicien'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byKey(const Key('create_submit')));
    expect(btn.onPressed, isNull); // bouton désactivé tant que les listes sont vides
  });

  testWidgets('avec self : l\'option "Moi (vous)" apparaît et produit assigneeId==self',
      (tester) async {
    String? assignee;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: true,
        self: const (id: 'mgr', name: 'Moi (vous)'),
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt,
            {required DomaineTrade domaine}) async {
          assignee = assigneeId;
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('task_title')), 'Tâche perso');
    // Ouvrir le sélecteur d'assigné et choisir "Moi (vous)"
    await tester.tap(find.text('Awono')); // valeur par défaut (1er technicien) affichée
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moi (vous)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();

    expect(assignee, 'mgr');
  });

  testWidgets('self seul (aucun technicien) : soumission possible', (tester) async {
    String? assignee;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: const [], isOnline: true,
        self: const (id: 'mgr', name: 'Moi (vous)'),
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt,
            {required DomaineTrade domaine}) async {
          assignee = assigneeId;
        },
      ),
    ));
    await tester.enterText(find.byKey(const Key('task_title')), 'Solo');
    final btn = tester.widget<ElevatedButton>(find.byKey(const Key('create_submit')));
    expect(btn.onPressed, isNotNull); // bouton actif : self suffit
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();
    expect(assignee, 'mgr'); // self pré-sélectionné faute de technicien
  });

  testWidgets('sélecteur domaine présent, valeur transmise via onCreate', (tester) async {
    DomaineTrade? captured;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: true,
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt,
            {required DomaineTrade domaine}) async {
          captured = domaine;
        },
      ),
    ));

    // Le sélecteur est visible
    expect(find.byKey(const Key('domaine-selector')), findsOneWidget);

    // Valeur par défaut : Électricité
    await tester.enterText(find.byKey(const Key('task_title')), 'Test domaine');
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();
    expect(captured, DomaineTrade.electricite);

    // Changer vers Plomberie
    captured = null;
    await tester.tap(find.byKey(const Key('domaine-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plomberie').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();
    expect(captured, DomaineTrade.plomberie);
  });
}
