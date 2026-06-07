import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Enregistre/maintient le token FCM de l'utilisateur dans Firestore.
class FcmService {
  FcmService(this._fs, [this._messaging]);
  final FirebaseFirestore _fs;
  final FirebaseMessaging? _messaging;

  /// Écrit le token (idempotent via arrayUnion).
  Future<void> registerToken(String userId, String token) =>
      _fs.collection('users').doc(userId).set(
        {'fcmTokens': FieldValue.arrayUnion([token])},
        SetOptions(merge: true),
      );

  /// À appeler après le pont auth Firebase : demande la permission,
  /// récupère le token et l'enregistre, puis suit les rotations de token.
  Future<void> start(String userId) async {
    final messaging = _messaging ?? FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) await registerToken(userId, token);
    messaging.onTokenRefresh.listen((t) => registerToken(userId, t));
  }
}
