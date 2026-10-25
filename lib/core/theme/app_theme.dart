import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color background = isDark ? AppColors.darkCanvas : AppColors.canvas;
    final Color surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final Color surfaceHigh = isDark
        ? AppColors.darkSurfaceHigh
        : AppColors.surfaceMuted;
    final Color surfaceHighest = isDark
        ? AppColors.darkSurfaceHighest
        : const Color(0xFFE7EBE0);
    final Color ink = isDark ? AppColors.darkInk : AppColors.ink;
    final Color muted = isDark ? AppColors.darkMuted : AppColors.muted;
    final Color line = isDark ? AppColors.darkLine : AppColors.line;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.lime,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.lime : AppColors.forest,
      onPrimary: isDark ? AppColors.forest : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF2C4512)
          : const Color(0xFFE3F7C6),
      onPrimaryContainer: isDark ? AppColors.lime : AppColors.forest,
      secondary: isDark ? AppColors.mint : const Color(0xFF2C7A57),
      onSecondary: isDark ? AppColors.forest : Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF1C3A2C)
          : const Color(0xFFD8F3E5),
      onSecondaryContainer: isDark ? AppColors.mint : const Color(0xFF0C3B28),
      tertiary: isDark ? AppColors.lavender : const Color(0xFF5A4FB6),
      onTertiary: isDark ? AppColors.forest : Colors.white,
      tertiaryContainer: isDark
          ? const Color(0xFF322C5C)
          : const Color(0xFFE7E3FF),
      onTertiaryContainer: isDark
          ? AppColors.lavender
          : const Color(0xFF221B5A),
      error: isDark ? AppColors.coral : const Color(0xFFB3261E),
      onError: isDark ? const Color(0xFF3B0A04) : Colors.white,
      surface: background,
      onSurface: ink,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      outline: line,
      outlineVariant: line.withValues(alpha: isDark ? 0.8 : 1),
    );

    final TextTheme textTheme = _textTheme(ink, muted);
    final RoundedRectangleBorder rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: line,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
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
      iconTheme: IconThemeData(color: ink, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.lime : AppColors.forest,
          foregroundColor: isDark ? AppColors.forest : Colors.white,
          minimumSize: const Size(52, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0,
          ),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(52, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: BorderSide(color: line, width: 1.2),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.lime : AppColors.forest,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.lime : AppColors.forest,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: isDark
            ? AppColors.lime.withValues(alpha: 0.2)
            : const Color(0xFFDDEFC2),
        disabledColor: surfaceHigh,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? AppColors.lime : AppColors.forest,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.forest : Colors.white)
              : (isDark ? AppColors.darkMuted : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.lime : AppColors.forest)
              : (isDark ? AppColors.darkLine : AppColors.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkSurfaceHighest
            : AppColors.ink,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkInk : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: rounded,
        insetPadding: const EdgeInsets.fromLTRB(18, 0, 18, 94),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: line,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark ? AppColors.lime : AppColors.forest,
        selectionColor: AppColors.lime.withValues(alpha: 0.35),
        selectionHandleColor: isDark ? AppColors.lime : AppColors.forest,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.lime : AppColors.forest,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
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
        fontSize: 46,
        height: 1.06,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontSize: 38,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontSize: 31,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 27,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
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
  Color get pageBackground => Theme.of(this).scaffoldBackgroundColor;
}
