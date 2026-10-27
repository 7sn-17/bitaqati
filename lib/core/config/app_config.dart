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

  /// The public Web OAuth client id. This is the `serverClientId` that makes
  /// Google return an ID token whose audience Supabase can verify.
  ///
  /// Client IDs are public identifiers, not secrets. The **Android** client id
  /// is never used here: it only authorizes the package name and signing
  /// certificate in Google Cloud.
  static const String _defaultGoogleWebClientId =
      '610940162017-ohe2ei9dkkj96cai8gqu0i2jmgbspd8b.apps.googleusercontent.com';

  /// Optional build-time override. An empty `--dart-define` (the usual result
  /// of a missing CI secret) must not erase the safe default.
  static const String _googleWebClientIdOverride = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static String get googleWebClientId => _googleWebClientIdOverride.isEmpty
      ? _defaultGoogleWebClientId
      : _googleWebClientIdOverride;

  /// iOS OAuth client id. Only used on iOS builds.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get hasGoogleSignIn => googleWebClientId.isNotEmpty;
}
