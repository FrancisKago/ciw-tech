import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/outbox/outbox_uploader.dart';

void main() {
  test('drainOnce upload chaque photo et patche le doc en uploaded', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'userId': 'u1', 'photoStatus': 'pending'});
    await outbox.enqueue('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(
      fs, outbox,
      uploadFn: (punchId, path) async => 'https://storage/$punchId.jpg',
    );

    await uploader.drainOnce();

    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'uploaded');
    expect(doc.data()!['photoUrl'], 'https://storage/p1.jpg');
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('un upload qui échoue bumpAttempts et garde l\'élément', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending'});
    await outbox.enqueue('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(
      fs, outbox,
      uploadFn: (_, __) async => throw Exception('réseau'),
    );

    await uploader.drainOnce();

    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    await outbox.close();
  });
}
