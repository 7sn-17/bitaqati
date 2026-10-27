import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  if (AppConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
      );
    } catch (error) {
      // A broken Supabase config must not brick the offline experience.
      debugPrint('Supabase initialization failed: $error');
    }
  }

  runApp(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BitaqatiApp(),
    ),
  );
}
