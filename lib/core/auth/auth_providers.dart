import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_service.dart';
import '../providers.dart';

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(),
);

/// The signed-in Supabase user, or null for guests and signed-out users.
///
/// The stream starts with the session restored at launch, so the header never
/// flickers from "guest" to the real name on a warm start.
final StreamProvider<User?> currentUserProvider = StreamProvider<User?>((
  Ref ref,
) async* {
  final AuthService auth = ref.watch(authServiceProvider);
  yield auth.currentUser;
  await for (final AuthState state in auth.onAuthStateChange) {
    yield state.session?.user;
  }
});

/// Guest mode lets the user keep studying locally without an account.
final NotifierProvider<GuestModeNotifier, bool> guestModeProvider =
    NotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);

class GuestModeNotifier extends Notifier<bool> {
  static const String _key = 'guest_mode';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> enter() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }

  Future<void> exit() async {
    state = false;
    await ref.read(sharedPreferencesProvider).setBool(_key, false);
  }
}

/// Whether the app should treat the current user as signed in.
///
/// Read this through [Ref.read] (not `watch`) inside router redirects: the
/// underlying session lives in the Supabase client, so a fresh read always
/// reflects sign-in and sign-out immediately.
bool isSignedInNow(Ref ref) {
  if (ref.read(guestModeProvider)) {
    return true;
  }
  return ref.read(authServiceProvider).currentUser != null;
}

/// Bridges auth events into a [Listenable] so GoRouter re-runs its redirect
/// whenever the session starts, ends or a guest enters or leaves.
class AuthRefresh extends ChangeNotifier {
  void ping() {
    notifyListeners();
  }
}

final Provider<AuthRefresh> authRefreshProvider = Provider<AuthRefresh>((
  Ref ref,
) {
  final AuthRefresh refresh = AuthRefresh();
  final AuthService auth = ref.watch(authServiceProvider);
  final StreamSubscription<AuthState> subscription = auth.onAuthStateChange
      .listen((AuthState _) => refresh.ping());

  ref.listen<bool>(guestModeProvider, (bool? previous, bool next) {
    refresh.ping();
  });

  ref.onDispose(() {
    subscription.cancel();
    refresh.dispose();
  });

  return refresh;
});
