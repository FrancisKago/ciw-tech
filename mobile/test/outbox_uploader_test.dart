import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/outbox/outbox_uploader.dart';

void main() {
  test('drain upload une photo de pointage sous punches/{userId}/{punchId} et patche le punch',
      () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending', 'userId': 'u1'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    String? seenUserId;
    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, userId, path) async {
      seenUserId = userId;
      return 'https://storage/$userId/$ownerId.jpg';
    });
    await uploader.drainOnce();

    expect(seenUserId, 'u1');
    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'uploaded');
    expect(doc.data()!['photoUrl'], 'https://storage/u1/p1.jpg');
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('drain upload une photo de rapport et arrayUnion sur report.photoUrls (userId null)',
      () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('tasks').doc('t1').set({
      'status': 'done',
      'report': {'text': 'fait', 'photoUrls': <String>[], 'photoCount': 1},
    });
    await outbox.enqueueReport('t1', '/tmp/a.jpg');

    String? seenUserId = 'sentinelle';
    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, userId, path) async {
      seenUserId = userId;
      return 'https://storage/$ownerId/a.jpg';
    });
    await uploader.drainOnce();

    expect(seenUserId, isNull);
    final doc = await fs.collection('tasks').doc('t1').get();
    final report = doc.data()!['report'] as Map<String, dynamic>;
    expect(report['photoUrls'], contains('https://storage/t1/a.jpg'));
    expect(report['text'], 'fait');
    expect(report['photoCount'], 1);
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('un upload qui échoue bumpAttempts et garde l\'élément', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending', 'userId': 'u1'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (a, b, c, d) async => throw Exception('réseau'));
    await uploader.drainOnce();

    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    await outbox.close();
  });

  test('un punch sans userId lisible reste en attente sans upload ni patch', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    var uploadCalled = false;
    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, userId, path) async {
      uploadCalled = true;
      return 'https://storage/x.jpg';
    });
    await uploader.drainOnce();

    expect(uploadCalled, isFalse);
    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'pending');
    expect(doc.data()!.containsKey('photoUrl'), isFalse);
    await outbox.close();
  });
}
