// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_db.dart';

// ignore_for_file: type=lint
class $PendingPhotosTable extends PendingPhotos
    with TableInfo<$PendingPhotosTable, PendingPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _punchIdMeta = const VerificationMeta(
    'punchId',
  );
  @override
  late final GeneratedColumn<String> punchId = GeneratedColumn<String>(
    'punch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [punchId, localPath, attempts];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('punch_id')) {
      context.handle(
        _punchIdMeta,
        punchId.isAcceptableOrUnknown(data['punch_id']!, _punchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_punchIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {punchId};
  @override
  PendingPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPhoto(
      punchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}punch_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $PendingPhotosTable createAlias(String alias) {
    return $PendingPhotosTable(attachedDatabase, alias);
  }
}

class PendingPhoto extends DataClass implements Insertable<PendingPhoto> {
  final String punchId;
  final String localPath;
  final int attempts;
  const PendingPhoto({
    required this.punchId,
    required this.localPath,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['punch_id'] = Variable<String>(punchId);
    map['local_path'] = Variable<String>(localPath);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  PendingPhotosCompanion toCompanion(bool nullToAbsent) {
    return PendingPhotosCompanion(
      punchId: Value(punchId),
      localPath: Value(localPath),
      attempts: Value(attempts),
    );
  }

  factory PendingPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPhoto(
      punchId: serializer.fromJson<String>(json['punchId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'punchId': serializer.toJson<String>(punchId),
      'localPath': serializer.toJson<String>(localPath),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  PendingPhoto copyWith({String? punchId, String? localPath, int? attempts}) =>
      PendingPhoto(
        punchId: punchId ?? this.punchId,
        localPath: localPath ?? this.localPath,
        attempts: attempts ?? this.attempts,
      );
  PendingPhoto copyWithCompanion(PendingPhotosCompanion data) {
    return PendingPhoto(
      punchId: data.punchId.present ? data.punchId.value : this.punchId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhoto(')
          ..write('punchId: $punchId, ')
          ..write('localPath: $localPath, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(punchId, localPath, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPhoto &&
          other.punchId == this.punchId &&
          other.localPath == this.localPath &&
          other.attempts == this.attempts);
}

class PendingPhotosCompanion extends UpdateCompanion<PendingPhoto> {
  final Value<String> punchId;
  final Value<String> localPath;
  final Value<int> attempts;
  final Value<int> rowid;
  const PendingPhotosCompanion({
    this.punchId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingPhotosCompanion.insert({
    required String punchId,
    required String localPath,
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : punchId = Value(punchId),
       localPath = Value(localPath);
  static Insertable<PendingPhoto> custom({
    Expression<String>? punchId,
    Expression<String>? localPath,
    Expression<int>? attempts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (punchId != null) 'punch_id': punchId,
      if (localPath != null) 'local_path': localPath,
      if (attempts != null) 'attempts': attempts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingPhotosCompanion copyWith({
    Value<String>? punchId,
    Value<String>? localPath,
    Value<int>? attempts,
    Value<int>? rowid,
  }) {
    return PendingPhotosCompanion(
      punchId: punchId ?? this.punchId,
      localPath: localPath ?? this.localPath,
      attempts: attempts ?? this.attempts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (punchId.present) {
      map['punch_id'] = Variable<String>(punchId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhotosCompanion(')
          ..write('punchId: $punchId, ')
          ..write('localPath: $localPath, ')
          ..write('attempts: $attempts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OutboxDb extends GeneratedDatabase {
  _$OutboxDb(QueryExecutor e) : super(e);
  $OutboxDbManager get managers => $OutboxDbManager(this);
  late final $PendingPhotosTable pendingPhotos = $PendingPhotosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pendingPhotos];
}

typedef $$PendingPhotosTableCreateCompanionBuilder =
    PendingPhotosCompanion Function({
      required String punchId,
      required String localPath,
      Value<int> attempts,
      Value<int> rowid,
    });
typedef $$PendingPhotosTableUpdateCompanionBuilder =
    PendingPhotosCompanion Function({
      Value<String> punchId,
      Value<String> localPath,
      Value<int> attempts,
      Value<int> rowid,
    });

class $$PendingPhotosTableFilterComposer
    extends Composer<_$OutboxDb, $PendingPhotosTable> {
  $$PendingPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get punchId => $composableBuilder(
    column: $table.punchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingPhotosTableOrderingComposer
    extends Composer<_$OutboxDb, $PendingPhotosTable> {
  $$PendingPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get punchId => $composableBuilder(
    column: $table.punchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingPhotosTableAnnotationComposer
    extends Composer<_$OutboxDb, $PendingPhotosTable> {
  $$PendingPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get punchId =>
      $composableBuilder(column: $table.punchId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$PendingPhotosTableTableManager
    extends
        RootTableManager<
          _$OutboxDb,
          $PendingPhotosTable,
          PendingPhoto,
          $$PendingPhotosTableFilterComposer,
          $$PendingPhotosTableOrderingComposer,
          $$PendingPhotosTableAnnotationComposer,
          $$PendingPhotosTableCreateCompanionBuilder,
          $$PendingPhotosTableUpdateCompanionBuilder,
          (
            PendingPhoto,
            BaseReferences<_$OutboxDb, $PendingPhotosTable, PendingPhoto>,
          ),
          PendingPhoto,
          PrefetchHooks Function()
        > {
  $$PendingPhotosTableTableManager(_$OutboxDb db, $PendingPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> punchId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPhotosCompanion(
                punchId: punchId,
                localPath: localPath,
                attempts: attempts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String punchId,
                required String localPath,
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPhotosCompanion.insert(
                punchId: punchId,
                localPath: localPath,
                attempts: attempts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$OutboxDb,
      $PendingPhotosTable,
      PendingPhoto,
      $$PendingPhotosTableFilterComposer,
      $$PendingPhotosTableOrderingComposer,
      $$PendingPhotosTableAnnotationComposer,
      $$PendingPhotosTableCreateCompanionBuilder,
      $$PendingPhotosTableUpdateCompanionBuilder,
      (
        PendingPhoto,
        BaseReferences<_$OutboxDb, $PendingPhotosTable, PendingPhoto>,
      ),
      PendingPhoto,
      PrefetchHooks Function()
    >;

class $OutboxDbManager {
  final _$OutboxDb _db;
  $OutboxDbManager(this._db);
  $$PendingPhotosTableTableManager get pendingPhotos =>
      $$PendingPhotosTableTableManager(_db, _db.pendingPhotos);
}
