import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/outbox_db.dart';

void main() {
  late OutboxDb db;
  setUp(() => db = OutboxDb.memory());
  tearDown(() => db.close());

  test('enqueue puis pending retourne l\'élément', () async {
    await db.enqueue('p1', '/tmp/p1.jpg');
    final items = await db.pending();
    expect(items.length, 1);
    expect(items.first.localPath, '/tmp/p1.jpg');
  });

  test('remove vide la file', () async {
    await db.enqueue('p1', '/tmp/p1.jpg');
    await db.remove('p1');
    expect(await db.count(), 0);
  });

  test('bumpAttempts incrémente', () async {
    await db.enqueue('p1', '/tmp/p1.jpg');
    await db.bumpAttempts('p1');
    final row = (await db.pending()).first;
    expect(row.attempts, 1);
  });
}
