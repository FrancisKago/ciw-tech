// Wrapper fin autour de clerk_flutter. Confirmer l'API exacte via la doc du package.
abstract class ClerkAuthService {
  /// Retourne le JWT de session Clerk de l'utilisateur connecté, ou null.
  Future<String?> sessionJwt();
}
