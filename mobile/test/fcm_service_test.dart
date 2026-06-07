import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/notifications/fcm_service.dart';

void main() {
  test('registerToken ajoute le token dans users/{uid}.fcmTokens (arrayUnion)', () async {
    final fs = FakeFirebaseFirestore();
    final svc = FcmService(fs);

    await svc.registerToken('user_1', 'tok_abc');

    final doc = await fs.collection('users').doc('user_1').get();
    expect(List<String>.from(doc.data()!['fcmTokens']), contains('tok_abc'));
  });

  test('registerToken est idempotent (pas de doublon)', () async {
    final fs = FakeFirebaseFirestore();
    final svc = FcmService(fs);

    await svc.registerToken('user_1', 'tok_abc');
    await svc.registerToken('user_1', 'tok_abc');

    final doc = await fs.collection('users').doc('user_1').get();
    expect(List<String>.from(doc.data()!['fcmTokens']).length, 1);
  });
}
