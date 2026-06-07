import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/models/punch.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/pointage/punch_repository.dart';

void main() {
  test('createPunch écrit le doc Firestore ET enqueue la photo', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    final repo = PunchRepository(fs, outbox);

    final id = await repo.createPunch(
      userId: 'u1', kind: PunchKind.checkIn,
      lat: 4.0, lng: 9.0, accuracy: 10, siteId: 's1', photoPath: '/tmp/a.jpg',
      now: DateTime.utc(2026, 6, 5, 8),
    );

    final doc = await fs.collection('punches').doc(id).get();
    expect(doc.exists, true);
    expect(doc.data()!['userId'], 'u1');
    expect(doc.data()!['photoStatus'], 'pending');

    final pending = await outbox.pending();
    expect(pending.single.ownerId, id);
    expect(pending.single.kind, 'punch');
    expect(pending.single.localPath, '/tmp/a.jpg');
    await outbox.close();
  });

  test('createPunch enregistre le taskId fourni', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    final repo = PunchRepository(fs, outbox);
    final id = await repo.createPunch(
      userId: 'u1', kind: PunchKind.checkIn,
      lat: 4, lng: 9, accuracy: 10, siteId: 's1',
      photoPath: '/tmp/a.jpg', taskId: 't1');
    final doc = await fs.collection('punches').doc(id).get();
    expect(doc.data()!['taskId'], 't1');
    expect(doc.data()!['siteId'], 's1');
    await outbox.close();
  });
}
