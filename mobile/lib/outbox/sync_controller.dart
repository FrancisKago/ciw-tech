import 'dart:async';

/// Déclenche la vidange de l'outbox (upload des photos) :
/// - une fois immédiatement au démarrage (cas "déjà en ligne") ;
/// - à chaque passage en ligne ;
/// - périodiquement (filet de sécurité, ex. toutes les 20 s).
class SyncController {
  SyncController({
    required Stream<bool> onlineStream,
    required Future<void> Function() drain,
    Duration period = const Duration(seconds: 20),
  })  : _onlineStream = onlineStream,
        _drain = drain,
        _period = period;

  final Stream<bool> _onlineStream;
  final Future<void> Function() _drain;
  final Duration _period;
  StreamSubscription<bool>? _sub;
  Timer? _timer;

  void start() {
    _drain(); // tentative immédiate (la connexion peut déjà être active)
    _sub = _onlineStream.listen((online) {
      if (online) _drain();
    });
    _timer = Timer.periodic(_period, (_) => _drain());
  }

  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
  }
}
