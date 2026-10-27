import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

/// A sign-in problem whose [message] is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AuthFailure(${code ?? 'unknown'}): $message';
}

/// Native Google sign-in backed by Supabase Auth.
///
/// The flow never opens a browser:
/// 1. `google_sign_in` shows the operating system's account picker.
/// 2. Google returns an OpenID Connect ID token.
/// 3. Supabase exchanges that token for its own session with
///    `signInWithIdToken`.
class AuthService {
  AuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;

  static const List<String> _scopes = <String>['email', 'profile'];

  bool _googleInitialized = false;

  /// True when the build was given a Supabase URL and publishable key.
  bool get isSupabaseReady => AppConfig.hasSupabase;

  /// True when the build was given a Google web client id.
  bool get isGoogleReady => AppConfig.hasGoogleSignIn;

  User? get currentUser =>
      AppConfig.hasSupabase ? Supabase.instance.client.auth.currentUser : null;

  /// Emits on sign-in, sign-out and token refresh. Empty when Supabase is not
  /// configured, so callers can always subscribe safely.
  Stream<AuthState> get onAuthStateChange => AppConfig.hasSupabase
      ? Supabase.instance.client.auth.onAuthStateChange
      : const Stream<AuthState>.empty();

  /// Prepares the native Google SDK. Safe to call more than once.
  Future<void> initializeGoogle() async {
    if (_googleInitialized || !AppConfig.hasGoogleSignIn) {
      return;
    }
    await _googleSignIn.initialize(
      serverClientId: AppConfig.googleWebClientId.isEmpty
          ? null
          : AppConfig.googleWebClientId,
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
    );
    _googleInitialized = true;
  }

  /// Opens the native account picker and starts a Supabase session.
  Future<User> signInWithGoogle() async {
    _ensureConfigured();
    await initializeGoogle();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (error) {
      throw AuthFailure(_describe(error), code: error.code.name);
    }

    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure(
        'لم يُرجع Google رمز الهوية. تحقّق من معرّف العميل في Google Cloud.',
        code: 'missing-id-token',
      );
    }

    // The access token is optional for Supabase, so a failure to obtain it must
    // not block the sign-in.
    final String? accessToken = await _accessTokenFor(account);

    try {
      final AuthResponse response = await Supabase.instance.client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
      final User? user = response.user;
      if (user == null) {
        throw const AuthFailure(
          'لم تُنشئ Supabase جلسة لهذا الحساب.',
          code: 'no-session',
        );
      }
      return user;
    } on AuthException catch (error) {
      throw AuthFailure(error.message, code: error.code);
    }
  }

  /// Ends the Supabase session and forgets the Google account.
  Future<void> signOut() async {
    if (AppConfig.hasSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
    if (_googleInitialized) {
      try {
        await _googleSignIn.signOut();
      } on GoogleSignInException {
        // Already signed out; nothing to do.
      }
    }
  }

  Future<String?> _accessTokenFor(GoogleSignInAccount account) async {
    try {
      final GoogleSignInClientAuthorization? authorization = await account
          .authorizationClient
          .authorizationForScopes(_scopes);
      return authorization?.accessToken;
    } on GoogleSignInException {
      return null;
    }
  }

  void _ensureConfigured() {
    if (!AppConfig.hasSupabase) {
      throw const AuthFailure(
        'Supabase غير مهيّأ في هذا البناء. مرّر SUPABASE_URL و '
        'SUPABASE_PUBLISHABLE_KEY.',
        code: 'supabase-not-configured',
      );
    }
    if (!AppConfig.hasGoogleSignIn) {
      throw const AuthFailure(
        'تسجيل الدخول بجوجل غير مهيّأ. مرّر GOOGLE_WEB_CLIENT_ID.',
        code: 'google-not-configured',
      );
    }
  }

  String _describe(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'تم إلغاء تسجيل الدخول.';
      case GoogleSignInExceptionCode.interrupted:
        return 'توقف تسجيل الدخول قبل اكتماله. حاول مرة أخرى.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'إعداد عميل Google غير مكتمل. تحقّق من SHA-1 في Google Cloud.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'خدمات Google Play غير متاحة أو تحتاج تحديثاً.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'تعذّر عرض نافذة اختيار الحساب الآن.';
      default:
        return error.description ?? 'تعذّر تسجيل الدخول بجوجل.';
    }
  }
}
