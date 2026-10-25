import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/deck/deck_detail_screen.dart';
import '../../features/decks/decks_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../providers.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final bool onboarded = ref.read(onboardingCompletedProvider);

  // Re-evaluate redirects whenever onboarding, guest mode or auth changes.
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(onboardingCompletedProvider, (_, __) => refresh.value++);
  ref.listen(guestModeProvider, (_, __) => refresh.value++);
  ref.listen(authUserProvider, (_, __) => refresh.value++);

  bool signedIn() =>
      ref.read(authUserProvider).valueOrNull != null ||
      ref.read(authServiceProvider).currentUser != null;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: onboarded ? '/home' : '/onboarding',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final bool done = ref.read(onboardingCompletedProvider);
      final String at = state.matchedLocation;
      if (!done) {
        return at == '/onboarding' ? null : '/onboarding';
      }
      if (at == '/onboarding') {
        return '/home';
      }
      final bool needsLogin = ref.read(supabaseConfiguredProvider) &&
          !signedIn() &&
          !ref.read(guestModeProvider);
      if (needsLogin) {
        return at == '/login' ? null : '/login';
      }
      if (at == '/login') {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) => AppShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/decks',
                builder: (BuildContext context, GoRouterState state) =>
                    const DecksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                builder: (BuildContext context, GoRouterState state) =>
                    const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/progress',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProgressScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SearchScreen(),
      ),
      GoRoute(
        path: '/deck/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            DeckDetailScreen(deckId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/review/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            ReviewScreen(deckId: state.pathParameters['id']!),
      ),
    ],
  );
});
