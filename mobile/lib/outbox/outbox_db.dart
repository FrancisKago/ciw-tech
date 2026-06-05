import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'outbox_db.g.dart';

class PendingPhotos extends Table {
  TextColumn get punchId => text()();
  TextColumn get localPath => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {punchId};
}

@DriftDatabase(tables: [PendingPhotos])
class OutboxDb extends _$OutboxDb {
  OutboxDb(super.e);
  factory OutboxDb.memory() => OutboxDb(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<void> enqueue(String punchId, String localPath) =>
      into(pendingPhotos).insertOnConflictUpdate(
          PendingPhotosCompanion.insert(punchId: punchId, localPath: localPath));

  Future<List<PendingPhoto>> pending() => select(pendingPhotos).get();

  Future<void> remove(String punchId) =>
      (delete(pendingPhotos)..where((t) => t.punchId.equals(punchId))).go();

  Future<void> bumpAttempts(String punchId) async {
    final row = await (select(pendingPhotos)..where((t) => t.punchId.equals(punchId))).getSingle();
    await (update(pendingPhotos)..where((t) => t.punchId.equals(punchId)))
        .write(PendingPhotosCompanion(attempts: Value(row.attempts + 1)));
  }

  Future<int> count() async =>
      (await select(pendingPhotos).get()).length;
}
