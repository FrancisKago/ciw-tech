import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/tasks/home_shell.dart';

void main() {
  testWidgets('un manager voit les 3 onglets (Pointage, Mes tâches, Tâches créées)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        role: 'manager', userId: 'mgr',
        pointageTab: const Text('POINTAGE'),
        myTasksTab: const Text('MES_TACHES'),
        managerTasksTab: const Text('TACHES_CREEES'),
      ),
    ));
    // Libellés de la barre de navigation (toujours rendus, même hors écran)
    expect(find.text('Pointage'), findsOneWidget);
    expect(find.text('Mes tâches'), findsOneWidget);
    expect(find.text('Tâches créées'), findsOneWidget);
    // Onglet par défaut = Pointage (contenu visible)
    expect(find.text('POINTAGE'), findsOneWidget);
    // Bascule vers "Tâches créées"
    await tester.tap(find.text('Tâches créées'));
    await tester.pumpAndSettle();
    expect(find.text('TACHES_CREEES'), findsOneWidget);
  });

  testWidgets('un technicien voit Pointage + Mes tâches', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        role: 'technician', userId: 'tech_1',
        pointageTab: const Text('POINTAGE'),
        myTasksTab: const Text('MES_TACHES'),
        managerTasksTab: const Text('TACHES_CREEES'),
      ),
    ));
    expect(find.text('POINTAGE'), findsOneWidget);
    expect(find.text('TACHES_CREEES'), findsNothing);
  });
}
