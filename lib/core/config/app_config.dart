/// Build-time configuration.
///
/// The Supabase publishable key is safe to ship in the client. Never put a
/// service-role key or an AI provider key in the app.
abstract final class AppConfig {
  static const String appNameAr = 'بطاقاتي';
  static const String appNameEn = 'Bitaqati';

  /// Fallback only: the real version is read from the Android manifest at
  /// runtime (`appVersionProvider`), so the number on screen can never drift
  /// from the APK that is installed.
  static const String appVersion = '1.3.0';

  /// Custom URL scheme kept for links that were already shared.
  ///
  /// New links use HTTPS so they can travel through WhatsApp, Telegram and any
  /// browser; the custom scheme only stays as a compatibility path.
  static const String shareScheme = 'bitaqati';

  /// Public web host that serves the deck preview page and the
  /// `assetlinks.json` file used for Android App Links verification.
  static const String shareHost = 'bitaqati.app';

  /// SharedPreferences key for a link that arrived before sign-in completed.
  static const String pendingDeckKey = 'pending_deck_id';

  /// Extracts a deck id from a share link, or null for unrelated links.
  ///
  /// Accepts `https://bitaqati.app/deck/<id>` and the old
  /// `bitaqati://deck/<id>` form.
  static String? deckIdFromShareLink(Uri uri) {
    if (uri.scheme == shareScheme && uri.host == 'deck') {
      if (uri.pathSegments.isEmpty) {
        return null;
      }
      final String id = uri.pathSegments.first.trim();
      return id.isEmpty ? null : id;
    }
    final bool web =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.host == shareHost || uri.host == 'www.$shareHost');
    if (!web) {
      return null;
    }
    final List<String> segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != 'deck') {
      return null;
    }
    final String id = segments[1].trim();
    return id.isEmpty ? null : id;
  }

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
