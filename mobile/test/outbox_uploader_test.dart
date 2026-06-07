import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/outbox/outbox_uploader.dart';

void main() {
  test('drain upload une photo de pointage et patche le punch', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, path) async => 'https://storage/$ownerId.jpg');
    await uploader.drainOnce();

    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'uploaded');
    expect(doc.data()!['photoUrl'], 'https://storage/p1.jpg');
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('drain upload une photo de rapport et arrayUnion sur report.photoUrls', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('tasks').doc('t1').set({
      'status': 'done',
      'report': {'text': 'fait', 'photoUrls': <String>[], 'photoCount': 1},
    });
    await outbox.enqueueReport('t1', '/tmp/a.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, path) async => 'https://storage/$ownerId/a.jpg');
    await uploader.drainOnce();

    final doc = await fs.collection('tasks').doc('t1').get();
    final report = doc.data()!['report'] as Map<String, dynamic>;
    expect(report['photoUrls'], contains('https://storage/t1/a.jpg'));
    // Non-régression : le merge ne doit PAS écraser les champs frères du rapport.
    expect(report['text'], 'fait');
    expect(report['photoCount'], 1);
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('un upload qui échoue bumpAttempts et garde l\'élément', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (_, _, _) async => throw Exception('réseau'));
    await uploader.drainOnce();

    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    await outbox.close();
  });
}
