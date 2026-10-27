import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/create/card_editor_page.dart';
import '../../features/deck/deck_detail_screen.dart';
import '../../features/decks/decks_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/legal/privacy_policy_screen.dart';
import '../../features/legal/terms_of_service_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/developer_info_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../auth/auth_providers.dart';
import '../providers.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  // Re-runs the redirect below whenever the session or guest mode changes.
  final AuthRefresh refresh = ref.watch(authRefreshProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final bool onboarded = ref.read(onboardingCompletedProvider);
      final bool signedIn = isSignedInNow(ref);
      final String location = state.matchedLocation;
      final bool atOnboarding = location == '/onboarding';
      final bool atLogin = location == '/login';

      // 1. Onboarding comes first, once per install.
      if (!onboarded) {
        return atOnboarding ? null : '/onboarding';
      }
      // 2. Then authentication: session or guest mode.
      if (!signedIn) {
        return atLogin ? null : '/login';
      }
      // 3. Signed in: the entry screens are never shown again.
      if (atOnboarding || atLogin) {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
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
        path: '/developer',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const DeveloperInfoScreen(),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const TermsOfServiceScreen(),
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
        path: '/create-card',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) => CardEditorPage(
          deckId: state.uri.queryParameters['deckId'],
        ),
      ),
      GoRoute(
        path: '/edit-card/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) => CardEditorPage(
          cardId: state.pathParameters['id'],
          deckId: state.uri.queryParameters['deckId'],
        ),
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
