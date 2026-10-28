import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme_palette.dart';

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError('Override in main()'),
    );

final StateProvider<bool> onboardingCompletedProvider = StateProvider<bool>((
  Ref ref,
) {
  return ref.watch(sharedPreferencesProvider).getBool('onboarding_done') ??
      false;
});

final StateProvider<bool> notificationsEnabledProvider = StateProvider<bool>((
  Ref ref,
) {
  return ref.watch(sharedPreferencesProvider).getBool('notifications') ?? true;
});

/// A per-day cap the user can raise or lower in Settings.
///
/// The value is stored in SharedPreferences so it survives a restart without
/// needing the database, and it is clamped so a typo can never lock the user
/// out of studying.
class DailyLimitNotifier extends Notifier<int> {
  DailyLimitNotifier({
    required this.key,
    required this.fallback,
    required this.min,
    required this.max,
    required this.step,
  });

  final String key;
  final int fallback;
  final int min;
  final int max;
  final int step;

  @override
  int build() {
    final int? saved = ref.watch(sharedPreferencesProvider).getInt(key);
    return (saved ?? fallback).clamp(min, max);
  }

  Future<void> set(int value) async {
    final int next = value.clamp(min, max);
    state = next;
    await ref.read(sharedPreferencesProvider).setInt(key, next);
  }

  Future<void> increment() => set(state + step);

  Future<void> decrement() => set(state - step);
}

/// New cards introduced per study session.
final NotifierProvider<DailyLimitNotifier, int> dailyNewLimitProvider =
    NotifierProvider<DailyLimitNotifier, int>(
      () => DailyLimitNotifier(
        key: 'daily_new_limit',
        fallback: 10,
        min: 0,
        max: 200,
        step: 5,
      ),
    );

/// Review cards shown per study session.
final NotifierProvider<DailyLimitNotifier, int> dailyReviewLimitProvider =
    NotifierProvider<DailyLimitNotifier, int>(
      () => DailyLimitNotifier(
        key: 'daily_review_limit',
        fallback: 200,
        min: 20,
        max: 1000,
        step: 25,
      ),
    );

/// Tag chosen in the filter bar of the home and decks screens.
final StateProvider<String?> selectedTagProvider = StateProvider<String?>(
  (Ref ref) => null,
);

/// Tag chosen on the library screen.
final StateProvider<String?> libraryTagProvider = StateProvider<String?>(
  (Ref ref) => null,
);

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';

  @override
  ThemeMode build() {
    final String? saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }

  Future<void> toggleDark() async {
    await setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// The visual identity chosen in Settings.
///
/// Persisted by name, so adding a palette later never renumbers the saved
/// value, and an unknown string (a downgrade, a typo) falls back to Forest
/// instead of throwing.
final NotifierProvider<ThemePaletteNotifier, AppThemeId> themePaletteProvider =
    NotifierProvider<ThemePaletteNotifier, AppThemeId>(
      ThemePaletteNotifier.new,
    );

class ThemePaletteNotifier extends Notifier<AppThemeId> {
  static const String _key = 'theme_palette';

  @override
  AppThemeId build() {
    final String? saved = ref.watch(sharedPreferencesProvider).getString(_key);
    for (final AppThemeId id in AppThemeId.values) {
      if (id.name == saved) {
        return id;
      }
    }
    return AppThemeId.forest;
  }

  Future<void> select(AppThemeId id) async {
    if (state == id) {
      return;
    }
    state = id;
    await ref.read(sharedPreferencesProvider).setString(_key, id.name);
  }
}

/// App language chosen in Settings. Arabic is the default.
final NotifierProvider<LanguageNotifier, Locale> languageProvider =
    NotifierProvider<LanguageNotifier, Locale>(LanguageNotifier.new);

class LanguageNotifier extends Notifier<Locale> {
  static const String _key = 'language';

  @override
  Locale build() {
    // The app ships Arabic-only until the full localization pass, and the
    // language switch is hidden in Settings. Ignore any value persisted by an
    // earlier build so the UI can never be stuck in English/LTR with Arabic
    // copy and no way back.
    return const Locale('ar');
  }

  /// Switches the locale and text direction. Full English copy lands with the
  /// localization pass; until then the content stays Arabic.
  Future<void> setLanguage(String code) async {
    state = Locale(code == 'en' ? 'en' : 'ar');
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, state.languageCode);
  }
}
