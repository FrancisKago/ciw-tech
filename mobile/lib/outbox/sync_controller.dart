import 'dart:async';

class SyncController {
  SyncController({required Stream<bool> onlineStream, required Future<void> Function() drain})
      : _onlineStream = onlineStream, _drain = drain;
  final Stream<bool> _onlineStream;
  final Future<void> Function() _drain;
  StreamSubscription<bool>? _sub;

  void start() {
    _sub = _onlineStream.listen((online) {
      if (online) _drain();
    });
  }

  void dispose() => _sub?.cancel();
}
