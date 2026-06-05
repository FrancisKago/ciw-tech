import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/widgets/sync_badge.dart';

void main() {
  testWidgets('SyncBadge affiche le nombre en attente', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SyncBadge(pendingCount: 3))));
    expect(find.text('3 non synchronisé(s)'), findsOneWidget);
  });

  testWidgets('SyncBadge affiche "À jour" quand 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SyncBadge(pendingCount: 0))));
    expect(find.text('À jour'), findsOneWidget);
  });
}
