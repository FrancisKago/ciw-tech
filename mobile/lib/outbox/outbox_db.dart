import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'outbox_db.g.dart';

/// File d'attente générique d'uploads (photos) à synchroniser.
/// `kind` ∈ {'punch','report'} ; `ownerId` = punchId ou taskId.
class PendingUploads extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get ownerId => text()();
  TextColumn get localPath => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

/// Étapes SQL de migration v1→v2 (exposées pour être testées et rejouées).
const List<String> migrationV1toV2Sql = [
  'CREATE TABLE pending_uploads (id TEXT NOT NULL PRIMARY KEY, '
      'kind TEXT NOT NULL, owner_id TEXT NOT NULL, '
      'local_path TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0)',
  "INSERT INTO pending_uploads (id, kind, owner_id, local_path, attempts) "
      "SELECT punch_id, 'punch', punch_id, local_path, attempts FROM pending_photos",
  'DROP TABLE pending_photos',
];

@DriftDatabase(tables: [PendingUploads])
class OutboxDb extends _$OutboxDb {
  OutboxDb(super.e);
  factory OutboxDb.memory() => OutboxDb(NativeDatabase.memory());

  factory OutboxDb.open() {
    return OutboxDb(LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase(File(p.join(dir.path, 'outbox.sqlite')));
    }));
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from == 1) {
            for (final stmt in migrationV1toV2Sql) {
              await customStatement(stmt);
            }
          }
        },
      );

  String _uuid() => '${DateTime.now().microsecondsSinceEpoch}-${pendingUploads.hashCode}';

  /// Une photo de pointage : id stable = punchId (ré-enfiler écrase).
  Future<void> enqueuePunch(String punchId, String localPath) =>
      into(pendingUploads).insertOnConflictUpdate(PendingUpload(
          id: punchId, kind: 'punch', ownerId: punchId,
          localPath: localPath, attempts: 0));

  /// Une photo de rapport : id unique (plusieurs photos par tâche).
  Future<void> enqueueReport(String taskId, String localPath) =>
      into(pendingUploads).insert(PendingUpload(
          id: _uuid(), kind: 'report', ownerId: taskId,
          localPath: localPath, attempts: 0));

  Future<List<PendingUpload>> pending() => select(pendingUploads).get();

  Future<void> removeById(String id) =>
      (delete(pendingUploads)..where((t) => t.id.equals(id))).go();

  Future<void> bumpAttemptsById(String id) async {
    final row = await (select(pendingUploads)..where((t) => t.id.equals(id))).getSingle();
    await (update(pendingUploads)..where((t) => t.id.equals(id)))
        .write(PendingUploadsCompanion(attempts: Value(row.attempts + 1)));
  }

  Future<int> count() async => (await select(pendingUploads).get()).length;

  Stream<int> pendingCountStream() =>
      select(pendingUploads).watch().map((rows) => rows.length);
}
