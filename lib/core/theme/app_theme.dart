import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.accent : AppColors.primary,
          onPrimary: isDark ? AppColors.primary : Colors.white,
          secondary: isDark ? AppColors.accent : AppColors.primaryDeep,
          onSecondary: isDark ? AppColors.primary : Colors.white,
          surface: isDark ? AppColors.darkCanvas : AppColors.canvas,
          onSurface: isDark ? AppColors.darkInk : AppColors.ink,
          surfaceContainerHighest: isDark
              ? AppColors.darkSurface
              : AppColors.surface,
          surfaceContainerHigh: isDark
              ? AppColors.darkSurfaceHigh
              : AppColors.surface,
          outline: isDark ? AppColors.darkLine : AppColors.line,
          outlineVariant: isDark ? AppColors.darkLine : AppColors.line,
          error: AppColors.danger,
        );

    final textTheme = _textTheme(
      isDark ? AppColors.darkInk : AppColors.ink,
      isDark ? AppColors.darkMuted : AppColors.muted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'IBMPlexSansArabic',
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.accent : AppColors.primary,
          foregroundColor: isDark ? AppColors.primary : Colors.white,
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
          foregroundColor: scheme.primary,
          minimumSize: const Size(52, 50),
          side: BorderSide(color: scheme.primary, width: 1.2),
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
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.darkMuted : AppColors.muted,
        ),
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
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.7,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.primary : Colors.white)
              : (isDark ? AppColors.darkMuted : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.accent : AppColors.primary)
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

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}
