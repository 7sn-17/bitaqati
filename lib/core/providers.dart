import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_service.dart';
import '../data/content_repository.dart';
import '../domain/models.dart';
import 'config/app_config.dart';
import 'preferences/app_preferences.dart';

final Provider<AppPreferences> appPreferencesProvider = Provider<AppPreferences>((ref) => throw UnimplementedError());
final Provider<ContentRepository> contentRepositoryProvider = Provider<ContentRepository>((ref) => ContentRepository());
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) => AuthService());
final StreamProvider<AuthUser?> authUserProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authServiceProvider).userChanges);
final Provider<bool> supabaseConfiguredProvider = Provider<bool>((ref) => AppConfig.hasSupabase);

final FutureProvider<Catalog> catalogProvider = FutureProvider<Catalog>((ref) async {
  final user = ref.watch(authUserProvider).valueOrNull;
  final prefs = ref.watch(appPreferencesProvider);
  return ref.watch(contentRepositoryProvider).loadCatalog(displayName: user?.displayName ?? prefs.displayName);
});

final FutureProvider<int> pendingOutboxProvider = FutureProvider<int>((ref) async {
  ref.watch(catalogProvider);
  return ref.watch(contentRepositoryProvider).pendingOutboxCount();
});

final NotifierProvider<LocaleNotifier, Locale> localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.watch(appPreferencesProvider).languageCode == 'en' ? 'en' : 'ar');
  Future<void> setLanguage(String code) async {
    final safe = code == 'en' ? 'en' : 'ar';
    state = Locale(safe);
    await ref.read(appPreferencesProvider).setLanguageCode(safe);
  }
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(appPreferencesProvider).themeMode;
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(appPreferencesProvider).setThemeMode(mode);
  }
  void toggleDark() => setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final NotifierProvider<OnboardingNotifier, bool> onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(appPreferencesProvider).onboardingComplete;
  Future<void> complete() async {
    state = true;
    await ref.read(appPreferencesProvider).setOnboardingComplete(true);
  }
}

final NotifierProvider<GuestModeNotifier, bool> guestModeProvider = NotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);
class GuestModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(appPreferencesProvider).guestMode;
  Future<void> enterAsGuest() async { state = true; await ref.read(appPreferencesProvider).setGuestMode(true); }
  Future<void> leaveGuest() async { state = false; await ref.read(appPreferencesProvider).setGuestMode(false); }
}

final StateProvider<String?> selectedTagProvider = StateProvider<String?>((ref) => null);
final StateProvider<String> deckSortProvider = StateProvider<String>((ref) => 'due');
final StateProvider<bool> includeSubdecksProvider = StateProvider<bool>((ref) => true);
final StateProvider<String> searchQueryProvider = StateProvider<String>((ref) => '');
final StateProvider<int> librarySegmentProvider = StateProvider<int>((ref) => 0);
final StateProvider<int> progressRangeProvider = StateProvider<int>((ref) => 30);
final StateProvider<DateTime?> lastSyncProvider = StateProvider<DateTime?>((ref) => null);
final Provider<SharedPreferences> sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final StateProvider<bool> notificationsEnabledProvider = StateProvider<bool>((ref) => true);

// Restored to SubjectId? as expected by the UI
final StateProvider<SubjectId?> selectedSubjectProvider = StateProvider<SubjectId?>((ref) => null);
