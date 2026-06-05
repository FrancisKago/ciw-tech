import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  factory OutboxDb.open() {
    return OutboxDb(LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase(File(p.join(dir.path, 'outbox.sqlite')));
    }));
  }

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

  Stream<int> pendingCountStream() =>
      select(pendingPhotos).watch().map((rows) => rows.length);
}
