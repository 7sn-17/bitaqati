import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._prefs);

  static const String _onboardingKey = 'onboarding_complete_v2';
  static const String _languageKey = 'language_code';
  static const String _themeKey = 'theme_mode';
  static const String _lastSyncKey = 'last_sync_at';
  static const String _displayNameKey = 'display_name';
  static const String _guestKey = 'guest_mode';

  final SharedPreferences _prefs;

  static Future<AppPreferences> load() async {
    return AppPreferences(await SharedPreferences.getInstance());
  }

  bool get onboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  String get languageCode => _prefs.getString(_languageKey) ?? 'ar';

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  DateTime? get lastSyncAt {
    final String? raw = _prefs.getString(_lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool get guestMode => _prefs.getBool(_guestKey) ?? false;

  String? get displayName {
    final String? value = _prefs.getString(_displayNameKey);
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingKey, value);
  }

  Future<void> setLanguageCode(String value) async {
    await _prefs.setString(_languageKey, value == 'en' ? 'en' : 'ar');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setLastSyncAt(DateTime value) async {
    await _prefs.setString(_lastSyncKey, value.toUtc().toIso8601String());
  }

  Future<void> setGuestMode(bool value) async {
    await _prefs.setBool(_guestKey, value);
  }

  Future<void> setDisplayName(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(_displayNameKey);
    } else {
      await _prefs.setString(_displayNameKey, value.trim());
    }
  }
}
