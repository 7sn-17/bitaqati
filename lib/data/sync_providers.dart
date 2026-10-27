import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_providers.dart';
import 'local/database_provider.dart';
import 'sync_service.dart';

final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (Ref ref) => SyncService(ref.watch(appDatabaseProvider)),
);

/// Where the last sync left off, for the settings screen and any status chip.
class SyncState {
  const SyncState({this.running = false, this.report});

  final bool running;
  final SyncReport? report;
}

/// Runs a sync on sign-in and whenever a screen asks for one.
///
/// Keeping this in a notifier means the pull only happens once per session,
/// and a second tap on "sync now" cannot start a parallel pass.
final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends Notifier<SyncState> {
  bool _alive = true;

  @override
  SyncState build() {
    _alive = true;
    ref.onDispose(() => _alive = false);
    ref.listen<AsyncValue<User?>>(
      currentUserProvider,
      (AsyncValue<User?>? previous, AsyncValue<User?> next) {
        final User? user = next.valueOrNull;
        if (user != null && previous?.valueOrNull?.id != user.id) {
          // Deferred: the listener can fire while build() is still running,
          // and a notifier may not touch its own state during that window.
          unawaited(Future<void>.microtask(syncNow));
        }
      },
      fireImmediately: true,
    );
    return const SyncState();
  }

  Future<void> syncNow() async {
    if (!_alive || state.running) {
      return;
    }
    state = const SyncState(running: true);
    final SyncReport report = await ref.read(syncServiceProvider).run();
    if (!_alive) {
      return;
    }
    state = SyncState(report: report);
  }
}
