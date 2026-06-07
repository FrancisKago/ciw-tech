import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/outbox_db.dart';

void main() {
  late OutboxDb db;
  setUp(() => db = OutboxDb.memory());
  tearDown(() => db.close());

  test('enqueuePunch puis pending retourne un upload kind=punch', () async {
    await db.enqueuePunch('p1', '/tmp/p1.jpg');
    final items = await db.pending();
    expect(items.length, 1);
    expect(items.first.kind, 'punch');
    expect(items.first.ownerId, 'p1');
    expect(items.first.localPath, '/tmp/p1.jpg');
  });

  test('enqueueReport accepte plusieurs photos pour la même tâche', () async {
    await db.enqueueReport('task_1', '/tmp/a.jpg');
    await db.enqueueReport('task_1', '/tmp/b.jpg');
    final items = await db.pending();
    expect(items.where((i) => i.kind == 'report' && i.ownerId == 'task_1').length, 2);
  });

  test('removeById vide une ligne précise', () async {
    await db.enqueuePunch('p1', '/tmp/p1.jpg');
    final id = (await db.pending()).first.id;
    await db.removeById(id);
    expect(await db.count(), 0);
  });

  test('bumpAttemptsById incrémente', () async {
    await db.enqueuePunch('p1', '/tmp/p1.jpg');
    final id = (await db.pending()).first.id;
    await db.bumpAttemptsById(id);
    expect((await db.pending()).first.attempts, 1);
  });

  test('migration v1→v2 copie les pending_photos en uploads kind=punch', () async {
    // Reconstruit l'état v1 puis rejoue les étapes de migration exposées.
    await db.customStatement('DROP TABLE pending_uploads');
    await db.customStatement(
      'CREATE TABLE pending_photos (punch_id TEXT NOT NULL PRIMARY KEY, '
      'local_path TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0)');
    await db.customStatement(
      "INSERT INTO pending_photos (punch_id, local_path, attempts) "
      "VALUES ('p9', '/tmp/p9.jpg', 3)");
    for (final stmt in migrationV1toV2Sql) {
      await db.customStatement(stmt);
    }
    final rows = await db.pending();
    expect(rows.single.kind, 'punch');
    expect(rows.single.ownerId, 'p9');
    expect(rows.single.attempts, 3);
  });
}
