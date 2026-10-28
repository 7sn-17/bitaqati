import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'theme_palette.dart';

/// Builds the two [ThemeData] instances the app runs on, from one palette.
///
/// The palette is attached as a [ThemeExtension], which does two things at
/// once: every widget can read the active identity through the context, and
/// MaterialApp cross-fades it — [ThemePalette.lerp] is what turns a tap on a
/// swatch into an animated change instead of a flash.
abstract final class AppTheme {
  static ThemeData light([AppThemeId id = AppThemeId.forest]) =>
      build(id, Brightness.light);

  static ThemeData dark([AppThemeId id = AppThemeId.forest]) =>
      build(id, Brightness.dark);

  static ThemeData build(AppThemeId id, Brightness brightness) {
    final ThemePalette palette = ThemePalette.of(id, brightness);
    final bool isDark = palette.isDark;
    final Color ink = palette.ink;
    final Color muted = palette.muted;
    final Color page = palette.canvas;
    final Color card = palette.card;
    final Color raised = palette.raised;
    final Color hairline = palette.hairline;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? palette.brandInk : palette.primary,
          onPrimary: isDark ? palette.primary : palette.onPrimary,
          primaryContainer: isDark ? palette.raised : palette.accentSoft,
          onPrimaryContainer: isDark ? palette.brandInk : palette.onSoftAccent,
          secondary: isDark ? palette.brandInk : palette.primaryDeep,
          onSecondary: isDark ? palette.primary : palette.onPrimary,
          secondaryContainer: raised,
          onSecondaryContainer: ink,
          tertiary: isDark ? palette.accent : palette.info,
          onTertiary: isDark ? palette.primary : palette.onAccent,
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
          error: palette.danger,
          onError: palette.onPrimary,
        );

    final TextTheme textTheme = _textTheme(ink, muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
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
          backgroundColor: isDark ? palette.brandInk : palette.primary,
          foregroundColor: isDark ? palette.primary : palette.onPrimary,
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
          foregroundColor: isDark ? palette.brandInk : palette.primary,
          disabledForegroundColor: muted,
          minimumSize: const Size(52, 50),
          side: BorderSide(
            color: isDark ? palette.hairline : palette.primary,
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
          foregroundColor: isDark ? palette.brandInk : palette.primary,
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
        backgroundColor: isDark ? raised : card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? raised : ink,
        contentTextStyle: TextStyle(
          color: isDark ? ink : page,
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 0.7, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
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
          (Set<WidgetState> states) => Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? (isDark ? palette.brandInk : palette.primary)
              : hairline,
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

/// Theme-aware colours. Widgets read roles from here — never a literal — so a
/// palette switch reaches every corner of the product.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  /// The active identity. Falls back to Forest if a widget is built outside
  /// the app's theme (a bare test harness, a preview), so nothing throws.
  ThemePalette get palette {
    final ThemePalette? active = Theme.of(this).extension<ThemePalette>();
    if (active != null) {
      return active;
    }
    return ThemePalette.of(
      AppThemeId.forest,
      isDark ? Brightness.dark : Brightness.light,
    );
  }

  /// Page background.
  Color get canvas => palette.canvas;

  /// Deep brand fill.
  Color get primary => palette.primary;

  /// Darker step of the brand fill.
  Color get primaryDeep => palette.primaryDeep;

  /// Text on [primary].
  Color get onPrimary => palette.onPrimary;

  /// Bright highlight.
  Color get accent => palette.accent;

  /// A deeper step of [accent] for two-stop gradients.
  ///
  /// Forest used to hard-code a mid-green here, which made every gradient in
  /// the app end in the same leaf colour whatever the identity. Mixing the
  /// highlight toward the deep brand fill keeps the same visual weight while
  /// letting Ocean, Sunset and Classic own their own gradients.
  Color get accentDeep =>
      Color.lerp(palette.accent, palette.primaryDeep, 0.35)!;

  /// Text on [accent].
  Color get onAccent => palette.onAccent;

  /// Pale wash of [accent].
  Color get accentSoft => palette.accentSoft;

  /// Brand colour that stays legible as text: deep on light, bright on dark.
  Color get brandInk => palette.brandInk;

  /// Solid card background for the current theme.
  Color get cardSurface => palette.card;

  /// Inputs, chips and selected tabs inside a card.
  Color get raisedSurface => palette.raised;

  /// Soft brand wash used behind icons and highlights.
  Color get softAccent => palette.softAccent;

  /// Foreground for anything drawn on [softAccent].
  Color get onSoftAccent => palette.onSoftAccent;

  /// Stronger brand fill for a selected row.
  Color get selectedFill => palette.selectedFill;

  /// Danger colour, safe as a fill and as text on [cardSurface].
  Color get danger => palette.danger;

  /// Danger colour tuned for text on the current surface.
  Color get dangerInk => palette.dangerInk;

  /// Text and icons drawn on a [danger] fill.
  Color get onDanger =>
      ThemePalette.readable(const Color(0xFFFFFFFF), palette.danger);

  /// Background of a warning strip.
  Color get warningSurface => palette.warning;

  /// Text on [warningSurface].
  Color get warningInk => palette.warningInk;

  /// Informational accent (the old "blue").
  Color get info => palette.info;

  /// Gold used for ratings and rewards.
  Color get star => palette.star;

  /// Positive-result colour.
  Color get success => palette.success;

  /// Background of a review card once the answer is revealed.
  Color get answerSurface => palette.answerSurface;

  /// Text on [answerSurface].
  Color get onAnswer => palette.onAnswer;

  /// Primary text colour for the current theme.
  Color get ink => palette.ink;

  /// Secondary text colour for the current theme.
  Color get muted => palette.muted;

  /// A fixed colour made readable as *text* on this theme's surface.
  ///
  /// Stat tiles and subject chips take a brand colour each — deep green, blue,
  /// amber, pastel — and the deep ones vanish on a dark card while the pastels
  /// vanish on a light one. This is the single rule for that, shared with
  /// deckInk so a deck colour behaves the same everywhere it is drawn.
  Color legible(Color color) => deckInk(color, dark: isDark);

  /// Hairline colour for borders.
  Color get hairline => palette.hairline;
}
