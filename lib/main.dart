import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/preferences/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  
  // Initialize AppPreferences with the prefs instance
  final AppPreferences appPreferences = AppPreferences(prefs);

  runApp(
    ProviderScope(
      overrides: <Override>[
        // Override both providers so the app doesn't crash
        sharedPreferencesProvider.overrideWithValue(prefs),
        appPreferencesProvider.overrideWithValue(appPreferences),
      ],
      child: const BitaqatiApp(),
    ),
  );
}
