/// Build-time configuration.
///
/// The Supabase publishable key is safe to ship in the client. Never put a
/// service-role key or an AI provider key in the app.
abstract final class AppConfig {
  static const String appNameAr = 'بطاقاتي';
  static const String appNameEn = 'Bitaqati';
  static const String appVersion = '0.1.0';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
