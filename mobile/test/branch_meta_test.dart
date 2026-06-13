import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/branches/branch_meta.dart';
import 'package:pointage/branches/branch_chip.dart';

void main() {
  test('branchMeta mappe chaque branche', () {
    expect(branchMeta(DomaineTrade.electricite).label, 'Électricité');
    expect(branchMeta(DomaineTrade.informatique).icon, Icons.videocam);
    expect(branchMeta(DomaineTrade.plomberie).bg, const Color(0xFFE1F5EE));
    expect(branchMeta(DomaineTrade.autre).label, 'Autre');
  });
  test('branchMeta(null) = Non précisé', () {
    expect(branchMeta(null).label, 'Non précisé');
  });
  testWidgets('BranchChip affiche le libellé de la branche', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BranchChip(DomaineTrade.electricite)),
    ));
    expect(find.text('Électricité'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });
}
