import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'clerk_auth_service.dart';

String extractFirebaseToken(Map<dynamic, dynamic> data) {
  final token = data['firebaseToken'];
  if (token is! String) throw StateError('firebaseToken absent de la réponse');
  return token;
}

class FirebaseBridge {
  FirebaseBridge(this._clerk, this._functions, this._auth);
  final ClerkAuthService _clerk;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  /// Échange le JWT Clerk contre un jeton Firebase et connecte l'utilisateur.
  Future<void> signInToFirebase() async {
    final jwt = await _clerk.sessionJwt();
    if (jwt == null) throw StateError('Aucune session Clerk active');
    final callable = _functions.httpsCallable('mintFirebaseToken');
    final result = await callable.call(<String, dynamic>{'clerkJwt': jwt});
    final firebaseToken = extractFirebaseToken(result.data as Map);
    await _auth.signInWithCustomToken(firebaseToken);
  }
}
