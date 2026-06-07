import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/tasks/home_shell.dart';

void main() {
  testWidgets('un manager voit "Tâches créées" et le bouton Créer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        role: 'manager', userId: 'mgr',
        pointageTab: const Text('POINTAGE'),
        myTasksTab: const Text('MES_TACHES'),
        managerTasksTab: const Text('TACHES_CREEES'),
      ),
    ));
    expect(find.text('TACHES_CREEES'), findsOneWidget);
    expect(find.text('POINTAGE'), findsNothing);
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
