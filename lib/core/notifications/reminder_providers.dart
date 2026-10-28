import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content_providers.dart';
import '../../domain/models.dart';
import '../providers.dart';
import 'reminder_service.dart';

/// The process-wide reminder service.
final Provider<ReminderService> reminderServiceProvider =
    Provider<ReminderService>((Ref ref) => ReminderService.instance);

/// Whether the system currently allows reminders, for the settings row.
///
/// Invalidated when the app comes back to the foreground, because the user may
/// have changed the switch in system settings while it was away.
final FutureProvider<ReminderAccess> reminderAccessProvider =
    FutureProvider<ReminderAccess>(
      (Ref ref) => ReminderService.instance.access(),
    );

/// True when reminders may fire at an exact minute rather than within the hour.
final FutureProvider<bool> exactAlarmProvider = FutureProvider<bool>(
  (Ref ref) => ReminderService.instance.hasExactAlarms(),
);

/// Whether the learner asked for reminders at an exact minute.
///
/// Off by default, because an exact alarm wakes the device out of doze for a
/// nudge that nobody is timing with a stopwatch. The permission alone is not
/// consent: on Android 12 and 13 it is granted at install, which used to mean
/// every reminder was exact whether the user wanted it or not.
final NotifierProvider<ExactRemindersNotifier, bool> exactRemindersProvider =
    NotifierProvider<ExactRemindersNotifier, bool>(ExactRemindersNotifier.new);

class ExactRemindersNotifier extends Notifier<bool> {
  static const String _key = 'exact_reminders';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

/// Keeps the scheduled reminders in step with what is actually due.
///
/// The database emits on every answer, so the work is debounced: a whole
/// review session collapses into one reschedule at the end instead of six
/// plugin calls per card. Nothing is written when the visible outcome would be
/// identical, so an idle app never touches the notification manager.
class ReminderCoordinator {
  ReminderCoordinator(this._ref);

  final Ref _ref;

  Timer? _debounce;
  ({int slots, String? deckId})? _last;
  bool _disposed = false;

  /// Call whenever the amount of work changes, or when the app resumes.
  void schedule() {
    if (_disposed) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), apply);
  }

  /// Recomputes immediately, ignoring the debounce.
  Future<void> refresh() {
    _last = null;
    _debounce?.cancel();
    return apply();
  }

  Future<void> apply() async {
    if (_disposed) {
      return;
    }
    // The deck list is a stream; before its first frame the totals are all
    // zero. Scheduling from that would cancel every reminder each cold start,
    // so the coordinator simply waits for real data.
    if (!_ref.read(deckListProvider).hasValue) {
      return;
    }
    final bool enabled = _ref.read(notificationsEnabledProvider);
    final int due = _ref.read(totalDueProvider);
    final int slots = enabled ? ReminderService.slotsFor(due) : 0;
    final DeckNode? deck = _ref.read(todayReviewDeckProvider);
    final bool exact = _ref.read(exactRemindersProvider);
    final ({int slots, String? deckId, bool exact}) next = (
      slots: slots,
      deckId: deck?.id,
      exact: exact,
    );
    if (_last == next) {
      return;
    }
    _last = next;
    if (slots == 0) {
      await ReminderService.instance.cancelAll();
      return;
    }
    await ReminderService.instance.schedule(
      dueCount: due,
      deckId: deck?.id,
      deckTitle: deck?.title,
      exact: exact,
    );
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
  }
}

final Provider<ReminderCoordinator> reminderCoordinatorProvider =
    Provider<ReminderCoordinator>((Ref ref) {
      final ReminderCoordinator coordinator = ReminderCoordinator(ref);
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
