import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
