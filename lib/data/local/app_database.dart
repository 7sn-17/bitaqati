import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Offline-first store. This is the authoritative copy for studying; Supabase
/// is only a sync target and the public library.
@DriftDatabase(
  tables: <Type>[Decks, Cards, CardStates, ReviewLogs, SyncQueue, SyncMeta],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an in-memory executor in tests; production uses the default file.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bitaqati'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (Migrator migrator, int from, int to) async {
        if (from < 2) {
          // Phase C tightens the deck depth limit from 20 to 1. Legacy rows
          // that are deeper than a sub-deck are flattened onto level 1 so the
          // rebuilt table satisfies the new constraint; their cards stay
          // attached and remain editable.
          await customStatement('UPDATE decks SET depth = 1 WHERE depth > 1');
          // ignore: experimental_member_use
          await migrator.alterTable(TableMigration(decks));
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
