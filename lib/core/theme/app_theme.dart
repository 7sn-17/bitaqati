import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color ink = isDark ? AppColors.darkInk : AppColors.ink;
    final Color muted = isDark ? AppColors.darkMuted : AppColors.muted;
    final Color page = isDark ? AppColors.darkCanvas : AppColors.canvas;
    final Color card = isDark ? AppColors.darkSurface : Colors.white;
    final Color raised = isDark ? AppColors.darkSurfaceHigh : AppColors.surface;
    final Color hairline = isDark ? AppColors.darkLine : AppColors.line;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.darkAccent : AppColors.primary,
          onPrimary: isDark ? AppColors.primary : Colors.white,
          primaryContainer: isDark ? AppColors.darkSurfaceHigh : AppColors.accentSoft,
          onPrimaryContainer: isDark ? AppColors.darkAccent : AppColors.primary,
          secondary: isDark ? AppColors.darkAccent : AppColors.primaryDeep,
          onSecondary: isDark ? AppColors.primary : Colors.white,
          secondaryContainer: raised,
          onSecondaryContainer: ink,
          tertiary: isDark ? AppColors.accent : AppColors.blue,
          onTertiary: isDark ? AppColors.primary : Colors.white,
          surface: page,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerLowest: page,
          surfaceContainerLow: card,
          surfaceContainer: card,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: raised,
          outline: hairline,
          outlineVariant: hairline,
          error: isDark ? AppColors.darkDanger : AppColors.danger,
          onError: isDark ? AppColors.darkCanvas : Colors.white,
        );

    final TextTheme textTheme = _textTheme(ink, muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      canvasColor: page,
      cardColor: card,
      dividerColor: hairline,
      fontFamily: 'IBMPlexSansArabic',
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: ink),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: ink),
        actionsIconTheme: IconThemeData(color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
          foregroundColor: isDark ? AppColors.primary : Colors.white,
          disabledBackgroundColor: raised,
          disabledForegroundColor: muted,
          minimumSize: const Size(52, 52),
          textStyle: const TextStyle(
            fontFamily: 'ReadexPro',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
          disabledForegroundColor: muted,
          minimumSize: const Size(52, 50),
          side: BorderSide(
            color: isDark ? AppColors.darkLine : AppColors.primary,
            width: 1.2,
          ),
          textStyle: const TextStyle(
            fontFamily: 'ReadexPro',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
          disabledForegroundColor: muted,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceHigh : AppColors.ink,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkInk : Colors.white,
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 0.7,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.darkMuted : AppColors.muted,
        textColor: ink,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: raised,
        circularTrackColor: raised,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.primary : Colors.white)
              : (isDark ? AppColors.darkMuted : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.darkAccent : AppColors.primary)
              : (isDark ? AppColors.darkLine : AppColors.line),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color ink, Color muted) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 48,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 38,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 30,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 19,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.65,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }
}

/// Theme-aware colours. Widgets should read from here instead of reaching for
/// the raw palette, which is what made dark mode unreadable.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  /// Primary text colour for the current theme.
  Color get ink => isDark ? AppColors.darkInk : AppColors.ink;

  /// Secondary text colour for the current theme.
  Color get muted => isDark ? AppColors.darkMuted : AppColors.muted;

  /// Brand colour that stays legible: dark green on light, lime on dark.
  Color get brandInk => isDark ? AppColors.darkAccent : AppColors.primary;

  /// Solid card background for the current theme.
  Color get cardSurface => isDark ? AppColors.darkSurface : Colors.white;

  /// Inputs, chips and selected tabs inside a card.
  Color get raisedSurface =>
      isDark ? AppColors.darkSurfaceHigh : AppColors.surface;

  /// Soft brand wash used behind icons and highlights.
  Color get softAccent => isDark
      ? AppColors.accent.withValues(alpha: 0.16)
      : AppColors.accentSoft;

  /// Foreground for anything drawn on [softAccent].
  ///
  /// The light palette pairs the pale wash with dark green ink; on a dark
  /// surface the same dark green disappears, so the pair flips to lime. Every
  /// "selected" chip, badge and privacy row must use both getters together --
  /// using [AppColors.primary] on [softAccent] is what made dark mode
  /// unreadable.
  Color get onSoftAccent => isDark ? AppColors.darkAccent : AppColors.primary;

  /// Stronger brand fill for a selected row: lime on dark, deep green on
  /// light, always with a foreground that clears 4.5:1.
  Color get selectedFill =>
      isDark ? AppColors.accent.withValues(alpha: 0.22) : AppColors.accentSoft;

  /// Danger colour that stays legible on both themes.
  Color get dangerInk => isDark ? AppColors.darkDanger : AppColors.danger;

  /// Hairline colour for borders.
  Color get hairline => isDark ? AppColors.darkLine : AppColors.line;
}
