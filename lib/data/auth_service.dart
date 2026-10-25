import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
}

class AuthService {
  bool _googleInitialized = false;

  bool get isConfigured => AppConfig.hasSupabase;

  SupabaseClient get _client => Supabase.instance.client;

  AuthUser? get currentUser {
    if (!isConfigured) {
      return null;
    }
    try {
      return _mapUser(_client.auth.currentUser);
    } on Object {
      return null;
    }
  }

  Stream<AuthUser?> get userChanges {
    if (!isConfigured) {
      return Stream<AuthUser?>.value(null);
    }
    try {
      return _client.auth.onAuthStateChange.map(
        (AuthState state) => _mapUser(state.session?.user),
      );
    } on Object {
      return Stream<AuthUser?>.value(null);
    }
  }

  /// Attempts the native Google account picker first. If Android rejects the
  /// native OAuth client (for example because no SHA-1 client is registered),
  /// the Supabase browser flow is used instead.
  Future<AuthUser?> signInWithGoogle() async {
    if (!isConfigured) {
      throw const AuthFailure('Auth is not configured.');
    }
    try {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('Google did not return an ID token.');
      }
      final AuthResponse response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return _mapUser(response.user ?? response.session?.user);
    } on Object {
      await _signInWithBrowser();
      return null;
    }
  }

  Future<void> _signInWithBrowser() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
      clientId: AppConfig.googleWebClientId,
    );
    _googleInitialized = true;
  }

  Future<void> signOut() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } on Object {
      // Native sign-out is best-effort; the Supabase session is authoritative.
    }
    if (isConfigured) {
      await _client.auth.signOut();
    }
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    final Map<String, dynamic> metadata =
        user.userMetadata ?? <String, dynamic>{};
    final String? name =
        metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        user.email?.split('@').first;
    final String? avatar =
        metadata['avatar_url'] as String? ?? metadata['picture'] as String?;
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: name,
      avatarUrl: avatar,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
