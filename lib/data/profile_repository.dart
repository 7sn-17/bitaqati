import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import 'local/app_database.dart';

/// A profile problem whose message is safe to show to the user.
class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Stores the display name the user picked, locally first and then in
/// Supabase.
///
/// The local row is the source of truth for this device: writing it first
/// means a rename works offline, survives a sign-out, and is never lost to a
/// dropped request. The cloud copy is what the public library reads.
class ProfileRepository {
  ProfileRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const int minNameLength = 2;
  static const int maxNameLength = 40;

  /// The chosen name, or an empty string when the user has not picked one.
  Stream<String> watchDisplayName(String userId) {
    return (_db.select(_db.profiles)
          ..where((Profiles p) => p.userId.equals(userId)))
        .watchSingleOrNull()
        .map((ProfileRow? row) => row?.displayName ?? '');
  }

  Future<String> readDisplayName(String userId) async {
    final ProfileRow? row =
        await (_db.select(_db.profiles)
              ..where((Profiles p) => p.userId.equals(userId)))
            .getSingleOrNull();
    return row?.displayName ?? '';
  }

  /// Saves [name] for [userId]. Throws [ProfileFailure] when it is unusable.
  ///
  /// The remote write is best effort: if it fails, the local value stays and
  /// the next sync pushes it.
  Future<void> setDisplayName(String userId, String name) async {
    final String clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < minNameLength || clean.length > maxNameLength) {
      throw const ProfileFailure(
        'الاسم يجب أن يكون بين حرفين و40 حرفاً.',
      );
    }
    await (_db.into(_db.profiles).insertOnConflictUpdate(
      ProfilesCompanion.insert(
        userId: userId,
        displayName: Value<String>(clean),
        updatedAt: Value<DateTime>(_clock()),
      ),
    ));
    try {
      await pushToCloud(userId);
    } catch (_) {
      // Offline, or the row is locked by RLS. The local copy is what the app
      // reads, and SyncService retries on the next pass.
    }
  }

  /// Writes the local name to Supabase. No-op when nothing was chosen yet.
  Future<void> pushToCloud(String userId) async {
    if (!AppConfig.hasSupabase) {
      return;
    }
    final ProfileRow? row =
        await (_db.select(_db.profiles)
              ..where((Profiles p) => p.userId.equals(userId)))
            .getSingleOrNull();
    final String name = row?.displayName.trim() ?? '';
    if (name.isEmpty) {
      return;
    }
    await Supabase.instance.client.from('profiles').upsert(<String, Object?>{
      'id': userId,
      'display_name': name,
      'display_name_custom': true,
    });
  }

  /// Adopts the cloud name when it was chosen deliberately and is newer than
  /// what this device has. Returns true when the local row changed.
  Future<bool> pullFromCloud(String userId) async {
    if (!AppConfig.hasSupabase) {
      return false;
    }
    final List<Map<String, dynamic>> rows = await Supabase.instance.client
        .from('profiles')
        .select('display_name,display_name_custom,updated_at')
        .eq('id', userId)
        .limit(1);
    if (rows.isEmpty) {
      return false;
    }
    final Map<String, dynamic> remote = rows.first;
    if (remote['display_name_custom'] != true) {
      // The name still comes from Google; this device's choice wins.
      return false;
    }
    final Object? rawName = remote['display_name'];
    final String name = rawName is String ? rawName.trim() : '';
    if (name.isEmpty) {
      return false;
    }
    final ProfileRow? local =
        await (_db.select(_db.profiles)
              ..where((Profiles p) => p.userId.equals(userId)))
            .getSingleOrNull();
    if (local != null && local.displayName == name) {
      return false;
    }
    final Object? rawUpdated = remote['updated_at'];
    final DateTime? remoteUpdated = rawUpdated is String
        ? DateTime.tryParse(rawUpdated)?.toLocal()
        : null;
    if (local != null &&
        remoteUpdated != null &&
        !remoteUpdated.isAfter(local.updatedAt)) {
      return false;
    }
    await (_db.into(_db.profiles).insertOnConflictUpdate(
      ProfilesCompanion.insert(
        userId: userId,
        displayName: Value<String>(name),
        updatedAt: Value<DateTime>(remoteUpdated ?? _clock()),
      ),
    ));
    return true;
  }
}
