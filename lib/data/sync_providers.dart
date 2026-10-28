import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_providers.dart';
import 'local/database_provider.dart';
import 'sync_service.dart';

final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (Ref ref) => SyncService(ref.watch(appDatabaseProvider)),
);

/// Whether the device currently has a network route, as a stream.
///
/// Kept here because the sync controller is the only other thing that cares,
/// and two subscriptions to the same platform channel would be wasteful.
final StreamProvider<bool> networkStatusProvider = StreamProvider<bool>((
  Ref ref,
) {
  return Connectivity().onConnectivityChanged
      .map(
        (List<ConnectivityResult> results) => results.any(
          (ConnectivityResult result) => result != ConnectivityResult.none,
        ),
      )
      .distinct();
});

/// Where the last sync left off, for the settings screen and any status chip.
class SyncState {
  const SyncState({this.running = false, this.report});

  final bool running;
  final SyncReport? report;
}

/// Runs a sync on sign-in, on reconnect, and when the app returns to the
/// foreground.
///
/// Keeping this in a notifier means a pull cannot overlap itself, and the
/// short cooldown below stops a burst of foreground events from turning into a
/// burst of round trips. There is deliberately no timer: nothing polls while
/// the app is idle.
final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends Notifier<SyncState> {
  bool _alive = true;
  bool _wasOffline = false;
  DateTime? _lastPass;
  StreamSubscription<List<ConnectivityResult>>? _network;

  /// Two foreground events in a row — returning from the image picker, for
  /// example — should not each cost a round trip. Anything within this window
  /// is treated as the same wake-up.
  static const Duration _cooldown = Duration(seconds: 20);

  @override
  SyncState build() {
    _alive = true;
    ref.onDispose(() => _alive = false);

    // Studying works entirely from the local database, so the app can sit
    // offline indefinitely. The moment the radio comes back we drain the queue
    // in the background, without the user having to ask for it.
    _network = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final bool online = results.any(
        (ConnectivityResult result) => result != ConnectivityResult.none,
      );
      if (!online) {
        _wasOffline = true;
        return;
      }
      if (_wasOffline) {
        _wasOffline = false;
        unawaited(Future<void>.microtask(syncNow));
      }
    });
    ref.onDispose(() => _network?.cancel());

    // No timer. A study session's writes are pushed on the three moments that
    // actually matter: when the radio comes back, when the app returns to the
    // foreground, and when the user asks. An idle app therefore never wakes the
    // radio, which is both kinder to the battery and cheaper than polling a
    // queue that is usually empty.
    ref.listen<AsyncValue<User?>>(currentUserProvider, (
      AsyncValue<User?>? previous,
      AsyncValue<User?> next,
    ) {
      final User? user = next.valueOrNull;
      if (user != null && previous?.valueOrNull?.id != user.id) {
        // Deferred: the listener can fire while build() is still running,
        // and a notifier may not touch its own state during that window.
        // Forced, because a sign-in must pull immediately even if the app
        // just resumed.
        unawaited(Future<void>.microtask(() => syncNow(force: true)));
      }
    }, fireImmediately: true);
    return const SyncState();
  }

  Future<void> syncNow({bool force = false}) async {
    if (!_alive || state.running) {
      return;
    }
    final DateTime? last = _lastPass;
    if (!force && last != null && DateTime.now().difference(last) < _cooldown) {
      return;
    }
    _lastPass = DateTime.now();
    state = const SyncState(running: true);
    final SyncReport report = await ref.read(syncServiceProvider).run();
    if (!_alive) {
      return;
    }
    state = SyncState(report: report);
  }
}
