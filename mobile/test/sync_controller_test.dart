import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/sync_controller.dart';

void main() {
  test('start() draine immédiatement, puis sur chaque passage online (pas offline)', () async {
    var drains = 0;
    final controller = StreamController<bool>();
    final sync = SyncController(
      onlineStream: controller.stream,
      drain: () async => drains++,
      period: const Duration(hours: 1), // timer périodique neutralisé pendant le test
    );
    sync.start();
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1); // drain immédiat au démarrage

    controller.add(true); // online
    await Future<void>.delayed(Duration.zero);
    expect(drains, 2);

    controller.add(false); // offline → pas de drain supplémentaire
    await Future<void>.delayed(Duration.zero);
    expect(drains, 2);

    await controller.close();
    sync.dispose();
  });
}
