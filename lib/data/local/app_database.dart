import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/enums.dart';
import '../../domain/fsrs.dart';

part 'app_database.g.dart';

/// Local-first content store. Every row is addressable by a client-generated
/// UUID, which makes Phase 2 sync idempotent: the cloud can upsert by id without
/// a second identity map.
@DataClassName('DeckRecord')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get colorHex => text().withDefault(const Constant('#163300'))();
  TextColumn get iconKey => text().withDefault(const Constant('layers'))();
  TextColumn get privacy => textEnum<DeckPrivacy>()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isStarter => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get depth => integer().withDefault(const Constant(0))();
  TextColumn get sourceTemplateId => text().nullable()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
  IntColumn get publishedAtMs => integer().nullable()();
  IntColumn get deletedAtMs => integer().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('CardRecord')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text()();
  TextColumn get kind => textEnum<CardKind>()();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get hint => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
  IntColumn get deletedAtMs => integer().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('CardStateRecord')
class CardStates extends Table {
  TextColumn get cardId => text()();
  TextColumn get state => textEnum<FsrsState>()();
  IntColumn get dueAtMs => integer()();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  IntColumn get elapsedDays => integer().withDefault(const Constant(0))();
  IntColumn get scheduledDays => integer().withDefault(const Constant(0))();
  IntColumn get learningStep => integer().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  IntColumn get lastReviewMs => integer().nullable()();
  BoolColumn get isSuspended => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuried => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cardId};
}

@DataClassName('ReviewLogRecord')
class ReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text()();
  IntColumn get rating => integer()();
  IntColumn get reviewedAtMs => integer()();
  IntColumn get elapsedMs => integer().nullable()();
  IntColumn get scheduledDays => integer().withDefault(const Constant(0))();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  TextColumn get previousState => text()();
  TextColumn get nextState => text()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('OutboxRecord')
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('MetadataRecord')
class Metadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DriftDatabase(
  tables: <Type>[
    Decks,
    Cards,
    CardStates,
    ReviewLogs,
    SyncOutbox,
    Metadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bitaqati'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Phase 2 sync columns are additive. Future migrations belong here and
      // must never drop a user's review history.
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
