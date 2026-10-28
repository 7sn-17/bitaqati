import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/config/app_config.dart';
import 'core/notifications/reminder_providers.dart';
import 'core/notifications/reminder_service.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_palette.dart';
import 'core/widgets/splash_screen.dart';
import 'data/icon_providers.dart';
import 'data/pro_providers.dart';
import 'data/sync_providers.dart';
import 'domain/freemium.dart';

class BitaqatiApp extends ConsumerStatefulWidget {
  const BitaqatiApp({super.key});

  @override
  ConsumerState<BitaqatiApp> createState() => _BitaqatiAppState();
}

class _BitaqatiAppState extends ConsumerState<BitaqatiApp>
    with WidgetsBindingObserver {
  late final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kicks off the first pull as soon as a session is restored, so a fresh
    // install on a new device shows the account's decks without a tap.
    ref.read(syncControllerProvider);
    // The launcher keeps whatever alias was enabled when the icon was last
    // changed, even across an update, so the icon on the home screen can drift
    // from the one this install is supposed to wear. Re-apply it once per
    // launch: a no-op when the two already agree.
    unawaited(ref.read(activeIconProvider.notifier).sync());
    // A reminder tapped while the app was closed is delivered as a launch
    // detail rather than a callback, so it is drained once the router exists.
    ReminderService.instance.onOpenDeck = _openReview;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final String? deckId = ReminderService.instance.takePendingDeck();
      if (deckId != null && mounted) {
        _openReview(deckId);
      }
    });
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object _) {
        // A malformed link must never crash the app.
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReminderService.instance.onOpenDeck = null;
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // Coming back from the background is the only moment the app can learn
    // that the user changed the notification switch, granted exact alarms, or
    // crossed into a new day. Syncing here replaces the old five-minute timer:
    // nothing polls while the app is idle.
    ref.invalidate(reminderAccessProvider);
    ref.invalidate(exactAlarmProvider);
    unawaited(ref.read(reminderCoordinatorProvider).refresh());
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  /// Opens the review screen for [deckId], or parks the request until the user
  /// has finished onboarding and signed in.
  void _openReview(String deckId) {
    final bool signedIn =
        ref.read(guestModeProvider) ||
        ref.read(authServiceProvider).currentUser != null;
    final bool ready = ref.read(onboardingCompletedProvider) && signedIn;
    if (!ready) {
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setString(AppConfig.pendingDeckKey, deckId),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      ref.read(routerProvider).push('/review/$deckId');
    });
  }

  Future<void> _handleUri(Uri uri) async {
    final String? deckId = AppConfig.deckIdFromShareLink(uri);
    if (deckId == null) {
      return;
    }
    final bool signedIn =
        ref.read(guestModeProvider) ||
        ref.read(authServiceProvider).currentUser != null;
    final bool ready = ref.read(onboardingCompletedProvider) && signedIn;
    if (!ready) {
      await ref
          .read(sharedPreferencesProvider)
          .setString(AppConfig.pendingDeckKey, deckId);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      ref.read(routerProvider).push('/deck/$deckId');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    // A paid palette is only worn by someone who has paid for it. A lapsed
    // subscriber keeps the colours they chose, the same grace the frozen
    // decks get; an install that never subscribed falls back to Forest even
    // if the saved preference says otherwise.
    final ProStatus pro = ref.watch(proNowProvider);
    final AppThemeId chosenPalette = ref.watch(themePaletteProvider);
    final AppThemeId paletteId =
        pro.everPro || chosenPalette == AppThemeId.forest
        ? chosenPalette
        : AppThemeId.forest;
    final Locale locale = ref.watch(languageProvider);
    final router = ref.watch(routerProvider);
    final bool isArabic = locale.languageCode == 'ar';

    return MaterialApp.router(
      title: isArabic ? AppConfig.appNameAr : AppConfig.appNameEn,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(paletteId),
      darkTheme: AppTheme.dark(paletteId),
      themeMode: themeMode,
      // A swatch tap is a change of identity, not a redraw. ThemeData.lerp
      // cross-fades the attached ThemePalette token by token, so the whole
      // screen dissolves from one identity into the next instead of snapping.
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      locale: locale,
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          // The splash covers the router for the first moment of the process
          // rather than being a route of its own, so a deep link or a
          // restored route is already where it belongs underneath.
          child: AnimatedSplash(
            arabic: isArabic,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
