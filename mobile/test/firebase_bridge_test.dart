import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/auth/firebase_bridge.dart';

void main() {
  test('extractFirebaseToken lit le champ firebaseToken de la réponse', () {
    expect(extractFirebaseToken({'firebaseToken': 'abc'}), 'abc');
  });

  test('extractFirebaseToken lève si le champ est absent', () {
    expect(() => extractFirebaseToken({}), throwsA(isA<StateError>()));
  });
}
