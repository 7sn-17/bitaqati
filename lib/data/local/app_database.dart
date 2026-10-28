import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Offline-first store. This is the authoritative copy for studying; Supabase
/// is only a sync target and the public library.
@DriftDatabase(
  tables: <Type>[
    Profiles,
    Decks,
    Cards,
    CardStates,
    ReviewLogs,
    SyncQueue,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an in-memory executor in tests; production uses the default file.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bitaqati'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (Migrator migrator, int from, int to) async {
        if (from < 3) {
          await migrator.addColumn(cards, cards.favorite);
        }
        if (from < 4) {
          // Decks are a flat list now, so parent_id, root_id, path, depth and
          // the depth CHECK constraint are all gone and share_code replaces
          // them. TableMigration rebuilds the table from the current schema
          // and copies every column that still exists, which keeps the decks
          // and their cards intact.
          // ignore: experimental_member_use
          await migrator.alterTable(TableMigration(decks));
        }
        if (from < 5) {
          // Attribution for remixes, plus the local profile row that stores
          // the display name the user picked in Settings.
          await migrator.createTable(profiles);
          await migrator.addColumn(decks, decks.originalDeckId);
          await migrator.addColumn(decks, decks.originalAuthorName);
        }
        if (from < 6) {
          // FSRS-6 bookkeeping. Rows that already exist keep the default 0,
          // which is exactly the marker the scheduler looks for when it
          // re-seeds a card that was scheduled by the old fixed intervals.
          await migrator.addColumn(cardStates, cardStates.fsrsVersion);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
