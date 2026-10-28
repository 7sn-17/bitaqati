import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/pro_providers.dart';
import '../../domain/freemium.dart';
import '../providers.dart';
import 'theme_palette.dart';

/// How long a free account may wear a paid palette before it snaps back.
///
/// One day is long enough to live with a theme through an evening of study and
/// short enough that it never replaces a subscription: the point is to show
/// what the paid tier looks like, not to give it away.
const Duration kThemeTrialLength = Duration(hours: 24);

/// A clock that moved backwards by more than this is treated as an attempt to
/// stretch a trial, not as a timezone change.
///
/// Real clock corrections (network time, a flight, a manual fix) land inside a
/// couple of minutes; a jump backwards big enough to matter does not.
const Duration _clockTolerance = Duration(minutes: 2);

/// One palette on trial, and the palettes whose one try is already spent.
///
/// [used] is separate from [theme] on purpose: it has to outlive the trial that
/// wrote it. A palette that was tried last month is still spent today.
@immutable
class ThemeTrialState {
  const ThemeTrialState({
    this.theme,
    this.startedAt,
    this.used = const <AppThemeId>{},
  });

  /// The palette currently on trial, or null when none is running.
  final AppThemeId? theme;

  /// When that trial began. The end is derived, so a stored end date can never
  /// disagree with the length the product promised.
  final DateTime? startedAt;

  /// Palettes whose single try has been used, whether or not it is still
  /// running.
  final Set<AppThemeId> used;

  bool get running => theme != null && startedAt != null;

  DateTime? get endsAt => startedAt?.add(kThemeTrialLength);

  /// Time left, never negative.
  Duration get remaining {
    final DateTime? end = endsAt;
    if (end == null) {
      return Duration.zero;
    }
    final Duration left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// True when [id] is the palette this trial is lending out and the clock has
  /// not run out on it.
  bool grants(AppThemeId id) =>
      running && theme == id && remaining > Duration.zero;

  /// True when [id] still has its one try and nothing else is running.
  ///
  /// One trial at a time: stacking three palettes would hand out three days of
  /// the paid tier in a row, which is a subscription, not a taste of one.
  bool canTry(AppThemeId id) => !used.contains(id) && !running;
}

/// Whether [id] may be worn right now.
///
/// Three answers, in this order: Forest is free, a paying account may wear
/// anything, and a free account may wear the palette its one try is lending it.
/// Anything else — a lapsed trial, a subscription that ended, a preference
/// edited by hand — falls back to Forest.
///
/// While the local profile row has not been read yet the saved value is
/// trusted, so a Pro account does not flash Forest for a frame on launch.
bool paletteAllowed(Ref ref, AppThemeId id) {
  if (id == AppThemeId.forest) {
    return true;
  }
  final AsyncValue<ProStatus> pro = ref.watch(proStatusProvider);
  if (!pro.hasValue) {
    return true;
  }
  // proNow, not the raw row: it is the one that knows the clock, so a palette
  // paid for until this evening is released this evening.
  if (ref.watch(proNowProvider).active) {
    return true;
  }
  return ref.watch(themeTrialProvider).grants(id);
}

/// The trial, as the app reads it.
final NotifierProvider<ThemeTrialController, ThemeTrialState>
themeTrialProvider = NotifierProvider<ThemeTrialController, ThemeTrialState>(
  ThemeTrialController.new,
);

class ThemeTrialController extends Notifier<ThemeTrialState> {
  static const String _themeKey = 'theme_trial_theme';
  static const String _startKey = 'theme_trial_start';
  static const String _usedKey = 'theme_trial_used';
  static const String _seenKey = 'theme_trial_seen';

  Timer? _timer;

  @override
  ThemeTrialState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    final ThemeTrialState stored = _read(prefs);
    _schedule(stored);
    return stored;
  }

  /// Starts the one try of [id]. Returns false when the palette is spent or
  /// another trial is already running.
  ///
  /// The record is written before the palette is switched, so a kill between
  /// the two leaves a spent palette rather than a free theme.
  Future<bool> start(AppThemeId id) async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    if (state.used.contains(id) || state.running) {
      return false;
    }
    if (ref.read(proNowProvider).active) {
      await ref.read(themePaletteProvider.notifier).select(id);
      return true;
    }
    final DateTime now = DateTime.now();
    final Set<AppThemeId> used = <AppThemeId>{...state.used, id};
    await prefs.setString(_themeKey, id.name);
    await prefs.setInt(_startKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_seenKey, now.millisecondsSinceEpoch);
    await prefs.setString(_usedKey, _encode(used));
    state = ThemeTrialState(theme: id, startedAt: now, used: used);
    _schedule(state);
    await ref.read(themePaletteProvider.notifier).select(id);
    return true;
  }

  /// Re-checks the trial against the wall clock.
  ///
  /// Called on launch, on every resume, and by the timer that fires when the
  /// trial ends. Three callers because none of them alone is enough: a phone
  /// can sleep through the timer, an app can be killed mid-trial, and a user
  /// can move the clock while the app is closed.
  Future<void> check() async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    final bool pro = ref.read(proNowProvider).active;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int? seen = prefs.getInt(_seenKey);
    final bool wentBack =
        seen != null && now < seen - _clockTolerance.inMilliseconds;

    // The anchor only ever moves forward. Writing the raw value would let a
    // backwards jump reset it on the next launch and erase the evidence.
    if (seen == null || now > seen) {
      await prefs.setInt(_seenKey, now);
    }

    if (wentBack) {
      // The only reason to move the clock back is to outlive the trial, so the
      // trial ends here. Nothing is lost: the palettes the user paid for are
      // untouched, and the one on trial is the only thing that changes.
      await _clear(prefs);
      if (!pro) {
        await ref.read(themePaletteProvider.notifier).reset();
      }
      return;
    }

    if (!state.running) {
      return;
    }
    if (pro) {
      // Upgrading mid-trial ends the trial, not the theme: a paying account
      // keeps whatever palette it is wearing.
      await _clear(prefs);
      return;
    }
    if (state.remaining > Duration.zero) {
      return;
    }
    await _clear(prefs);
    await ref.read(themePaletteProvider.notifier).reset();
  }

  ThemeTrialState _read(SharedPreferences prefs) {
    final Set<AppThemeId> used = _decode(prefs.getString(_usedKey));
    final String? name = prefs.getString(_themeKey);
    final int? start = prefs.getInt(_startKey);
    final AppThemeId? theme = _byName(name);
    if (theme == null || start == null) {
      return ThemeTrialState(used: used);
    }
    return ThemeTrialState(
      theme: theme,
      startedAt: DateTime.fromMillisecondsSinceEpoch(start),
      used: used,
    );
  }

  /// Ends the running trial and keeps [used] as it is: a palette that was
  /// tried is spent forever.
  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_themeKey);
    await prefs.remove(_startKey);
    state = ThemeTrialState(used: state.used);
    _timer?.cancel();
    _timer = null;
  }

  /// Fires once, at the moment the trial ends, so the palette snaps back while
  /// the app is open instead of waiting for the next launch.
  void _schedule(ThemeTrialState trial) {
    _timer?.cancel();
    _timer = null;
    if (!trial.running) {
      return;
    }
    final Duration left = trial.remaining;
    if (left <= Duration.zero) {
      return;
    }
    _timer = Timer(left, () => unawaited(check()));
  }

  static AppThemeId? _byName(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    for (final AppThemeId id in AppThemeId.values) {
      if (id.name == name) {
        return id;
      }
    }
    return null;
  }

  static String _encode(Set<AppThemeId> ids) =>
      ids.map((AppThemeId id) => id.name).join(',');

  static Set<AppThemeId> _decode(String? raw) {
    final Set<AppThemeId> out = <AppThemeId>{};
    if (raw == null || raw.isEmpty) {
      return out;
    }
    for (final String part in raw.split(',')) {
      final AppThemeId? id = _byName(part.trim());
      if (id != null) {
        out.add(id);
      }
    }
    return out;
  }
}

/// Time left on the running trial, refreshed while the settings screen is open.
///
/// A tick every twenty seconds is enough for a countdown that shows minutes,
/// and cheap enough to leave running while the card is visible.
final AutoDisposeStreamProvider<Duration> trialCountdownProvider =
    StreamProvider.autoDispose<Duration>((Ref ref) {
      final ThemeTrialState trial = ref.watch(themeTrialProvider);
      final DateTime? end = trial.endsAt;
      if (!trial.running || end == null) {
        return const Stream<Duration>.empty();
      }
      return _tick(end);
    });

Stream<Duration> _tick(DateTime end) async* {
  yield _left(end);
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 20));
    yield _left(end);
  }
}

Duration _left(DateTime end) {
  final Duration left = end.difference(DateTime.now());
  return left.isNegative ? Duration.zero : left;
}

/// `23:41`, the shape a countdown is read in.
String formatTrialLeft(Duration left) {
  final int hours = left.inHours;
  final int minutes = left.inMinutes % 60;
  return '$hours:${minutes.toString().padLeft(2, '0')}';
}
