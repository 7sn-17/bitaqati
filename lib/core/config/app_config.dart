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

  /// Web OAuth client id. Required on Android: it is the `serverClientId` that
  /// makes Google return an ID token for Supabase to verify.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// iOS OAuth client id. Only used on iOS builds.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get hasGoogleSignIn => googleWebClientId.isNotEmpty;
}
