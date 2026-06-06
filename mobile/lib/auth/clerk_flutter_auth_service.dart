import 'package:clerk_flutter/clerk_flutter.dart';
import 'clerk_auth_service.dart';

/// Implémentation concrète de [ClerkAuthService] adossée à clerk_flutter.
///
/// S'appuie sur le [ClerkAuthState] exposé par le widget `ClerkAuth` (récupéré
/// via `ClerkAuth.of(context)` ou le `signedInBuilder` de `ClerkAuthBuilder`).
class ClerkFlutterAuthService implements ClerkAuthService {
  ClerkFlutterAuthService(this._auth);

  final ClerkAuthState _auth;

  @override
  Future<String?> sessionJwt() async {
    // Pas d'utilisateur connecté => pas de JWT.
    if (_auth.user == null) return null;
    final token = await _auth.sessionToken();
    return token.jwt;
  }
}
