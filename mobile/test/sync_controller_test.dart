import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/sync_controller.dart';

void main() {
  test('un événement "online" déclenche drainOnce', () async {
    var drains = 0;
    final controller = StreamController<bool>();
    final sync = SyncController(
      onlineStream: controller.stream,
      drain: () async => drains++,
    );
    sync.start();
    controller.add(true);   // online
    await Future<void>.delayed(Duration.zero);
    controller.add(false);  // offline → pas de drain
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1);
    await controller.close();
    sync.dispose();
  });
}
