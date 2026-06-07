import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/pointage/geo_service.dart';
import 'package:pointage/pointage/photo_service.dart';
import 'package:pointage/pointage/punch_repository.dart';
import 'package:pointage/pointage/pointage_screen.dart';
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

  testWidgets('pré-sélectionne la tâche quand il n\'y en a qu\'une', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PointageScreen(
        userId: 'u1', geo: GeoService(), photo: PhotoService(),
        repo: PunchRepository(FakeFirebaseFirestore(), OutboxDb.memory()),
        pendingCount: 0,
        activeTasks: const [(taskId: 't1', siteId: 's1', title: 'Réparer')],
      ),
    ));
    expect(find.byKey(const Key('task_picker')), findsNothing); // pas de choix si une seule
  });
}
