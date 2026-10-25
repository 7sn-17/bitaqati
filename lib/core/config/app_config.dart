class AppConfig {
  const AppConfig._();

  // App Info
  static const String appNameAr = 'بطاقاتي';
  static const String appNameEn = 'Bitaqati';
  static const String appVersion = '0.2.0+2';

  // Deep Linking
  static const String appLinkScheme = 'com.bitaqati.app';
  static const String appLinkHost = 'login-callback';
  static const String oauthRedirect = '$appLinkScheme://$appLinkHost';

  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mftghnvtdryxzochquee.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_S057e6nIkK3vxrcvcUmZEw_tIKEM83W',
  );

  // Google Sign In
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '610940162017-ohe2ei9dkkj96cai8gqu0i2jmgbspd8b.apps.googleusercontent.com',
  );

  // Helpers
  static bool get hasSupabase =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  static bool get hasNativeGoogleClient => googleWebClientId.isNotEmpty;
}
