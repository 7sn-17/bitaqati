import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

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

final StateProvider<SubjectId?> selectedSubjectProvider =
    StateProvider<SubjectId?>((Ref ref) => null);

final StateProvider<SubjectId?> librarySubjectProvider =
    StateProvider<SubjectId?>((Ref ref) => null);

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
