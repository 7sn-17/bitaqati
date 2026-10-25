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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
