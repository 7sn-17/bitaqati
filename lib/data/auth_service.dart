import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
///
/// Native sign-in only works when all three pieces agree:
/// * the Android package name (`com.bitaqati.app`),
/// * the signing certificate SHA-1 (the release `bitaqati.p12`),
/// * the **Web** client id passed as `serverClientId`.
///
/// Diagnostics are logged with the `[GoogleAuth]` prefix. Tokens are never
/// logged; only their presence, length, and non-secret JWT claims.
class AuthService {
  AuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const String _logTag = '[GoogleAuth]';
  static const List<String> _scopes = <String>['email', 'profile'];

  final GoogleSignIn _googleSignIn;

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
    final String webClientId = AppConfig.googleWebClientId;
    final String iosClientId = AppConfig.googleIosClientId;

    _log('initialize: serverClientId=$webClientId');
    _log(
      'initialize: clientId=${iosClientId.isEmpty ? 'null (Android uses serverClientId)' : iosClientId}',
    );
    _log(
      'initialize: native auth requires package com.bitaqati.app and an APK '
      'signed with the registered release certificate.',
    );

    await _googleSignIn.initialize(
      serverClientId: webClientId.isEmpty ? null : webClientId,
      clientId: iosClientId.isEmpty ? null : iosClientId,
    );
    _googleInitialized = true;
    _log('initialize: GoogleSignIn ready.');
  }

  /// Opens the native account picker and starts a Supabase session.
  Future<User> signInWithGoogle() async {
    _ensureConfigured();

    final GoogleSignInAccount account;
    try {
      await initializeGoogle();
      account = await _googleSignIn.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (error, stackTrace) {
      _log(
        'authenticate failed: code=${error.code.name}, '
        'description=${error.description ?? '—'}',
      );
      _log('$stackTrace');
      throw AuthFailure(_describe(error), code: error.code.name);
    } on PlatformException catch (error, stackTrace) {
      _log(
        'authenticate PlatformException: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      _log('$stackTrace');
      throw AuthFailure(_describePlatform(error), code: error.code);
    } catch (error, stackTrace) {
      _log('authenticate unexpected ${error.runtimeType}: $error');
      _log('$stackTrace');
      throw const AuthFailure(
        'فشل التحقق من الحساب. تحقّق من اتصالك وحاول مرة أخرى.',
        code: 'unexpected',
      );
    }

    final String? idToken = account.authentication.idToken;
    _log(
      'account selected: idToken=${idToken == null ? 'null' : 'present (${idToken.length} chars)'}',
    );
    if (idToken != null && idToken.isNotEmpty) {
      _logIdTokenClaims(idToken);
    }

    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure(
        'لم يُرجع Google رمز الهوية. تحقّق من Web Client ID ومن SHA-1 في Google Cloud.',
        code: 'missing-id-token',
      );
    }

    // The access token is optional for Supabase, so a failure to obtain it must
    // not block the sign-in.
    final String? accessToken = await _accessTokenFor(account);
    _log('accessToken=${accessToken == null ? 'null' : 'present'}');

    try {
      _log(
        'signInWithIdToken: provider=google, '
        'serverClientId=${AppConfig.googleWebClientId}',
      );
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
      _log('Supabase session created: userId=${user.id}');
      return user;
    } on AuthException catch (error) {
      _log(
        'Supabase AuthException: code=${error.code ?? '—'}, '
        'message=${error.message}',
      );
      throw AuthFailure(_describeAuth(error), code: error.code);
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
      } on GoogleSignInException catch (error) {
        _log('signOut ignored GoogleSignInException: ${error.code.name}');
      } on PlatformException catch (error) {
        _log('signOut ignored PlatformException: ${error.code}');
      }
    }
  }

  Future<String?> _accessTokenFor(GoogleSignInAccount account) async {
    try {
      final GoogleSignInClientAuthorization? authorization = await account
          .authorizationClient
          .authorizationForScopes(_scopes);
      return authorization?.accessToken;
    } on GoogleSignInException catch (error) {
      _log('authorization failed: code=${error.code.name}');
      return null;
    } on PlatformException catch (error) {
      _log('authorization PlatformException: code=${error.code}');
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
        return 'تم إلغاء تسجيل الدخول. يمكنك المحاولة متى شئت.';
      case GoogleSignInExceptionCode.interrupted:
        return 'توقّف تسجيل الدخول قبل اكتماله. حاول مرة أخرى.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'فشل التحقق من الحساب. تحقّق من اتصالك وإعدادات Google '
            'ثم حاول مرة أخرى.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'خدمات Google Play غير متاحة أو تحتاج تحديثاً.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'تعذّر عرض نافذة اختيار الحساب الآن. حاول مرة أخرى.';
      default:
        return 'فشل التحقق من الحساب. تحقّق من اتصالك وحاول مرة أخرى.';
    }
  }

  String _describePlatform(PlatformException error) {
    final String code = error.code.toLowerCase();
    if (code.contains('cancel') || code == '16' || code == '12501') {
      return 'تم إلغاء تسجيل الدخول. يمكنك المحاولة متى شئت.';
    }
    return 'فشل التحقق من الحساب. تحقّق من اتصالك وحاول مرة أخرى.';
  }

  String _describeAuth(AuthException error) {
    final String code = (error.code ?? '').toLowerCase();
    if (code.contains('nonce')) {
      return 'فشل التحقق من الحساب بسبب عدم تطابق nonce. حاول مرة أخرى.';
    }
    if (code.contains('provider') || code.contains('token')) {
      return 'فشل التحقق من الحساب. تحقّق من اتصالك وحاول مرة أخرى.';
    }
    return error.message;
  }

  /// Logs the non-secret claims that determine whether Supabase will accept
  /// the token. `aud` must be the Web client id; `azp` shows which Android
  /// client actually signed the credential.
  void _logIdTokenClaims(String token) {
    try {
      final List<String> parts = token.split('.');
      if (parts.length < 2) {
        _log('idToken claims: malformed JWT');
        return;
      }
      final Map<String, dynamic> claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(parts[1])),
                ),
              )
              as Map<String, dynamic>;
      _log(
        'idToken claims: aud=${claims['aud']}, azp=${claims['azp']}, '
        'iss=${claims['iss']}, hasEmail=${claims['email'] != null}, '
        'hasNonce=${claims['nonce'] != null}',
      );
    } catch (error) {
      _log('idToken claims: decode failed ($error)');
    }
  }

  void _log(String message) => debugPrint('$_logTag $message');
}
