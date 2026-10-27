import 'package:flutter/material.dart';

/// Brand palette extracted from the original design.
///
/// Two rules keep the app readable in both themes:
/// 1. Never use [ink], [muted] or [surface] directly in a widget; use the
///    theme-aware getters in `app_theme.dart` (`context.ink`, `context.muted`,
///    `context.cardSurface`, `context.brandInk`).
/// 2. The dark palette is deliberately wider apart than the light one: on an
///    OLED phone a 4% step between two surfaces disappears completely.
abstract final class AppColors {
  // ---------------------------------------------------------------- light --
  static const Color primary = Color(0xFF163300);
  static const Color primaryDeep = Color(0xFF054D28);
  static const Color accent = Color(0xFF9FE870);
  static const Color accentSoft = Color(0xFFE2F6D5);
  static const Color canvas = Color(0xFFFAF9F5);
  static const Color surface = Color(0xFFEDF0E9);
  static const Color ink = Color(0xFF0E0F0C);
  static const Color muted = Color(0xFF5F6659);
  static const Color line = Color(0xFFDCE2D5);
  static const Color blue = Color(0xFF0B4C72);
  static const Color danger = Color(0xFFCB272F);
  static const Color warning = Color(0xFFFFF4D6);
  static const Color warningInk = Color(0xFF7A5300);

  // ----------------------------------------------------------------- dark --
  /// Page background. Almost black, but still green-tinted so the brand reads.
  static const Color darkCanvas = Color(0xFF080C08);

  /// Cards and grouped rows.
  static const Color darkSurface = Color(0xFF151D16);

  /// Raised elements inside a card: chips, inputs, selected tabs.
  static const Color darkSurfaceHigh = Color(0xFF212D22);

  /// Primary text. Pure white would vibrate on OLED; this is 94% white.
  static const Color darkInk = Color(0xFFF2F7EF);

  /// Secondary text. 7.4:1 against [darkSurface], so it passes WCAG AA.
  static const Color darkMuted = Color(0xFFB6C2B1);

  /// Hairlines and dividers.
  static const Color darkLine = Color(0xFF3B4A36);

  /// Accent tuned for text on dark backgrounds: the light-mode accent is too
  /// bright for large text, this one keeps 8.6:1 contrast on [darkSurface].
  static const Color darkAccent = Color(0xFFA9F27D);

  /// Danger tuned for dark backgrounds.
  static const Color darkDanger = Color(0xFFFF8A8A);

  /// Background of the review card once the answer is revealed. Lighter than
  /// [primary] so the card separates from the green page behind it.
  static const Color answerSurface = Color(0xFF2B5A1A);

  /// Slightly lifted green used for the review page in dark mode.
  static const Color darkAnswerSurface = Color(0xFF1D3D12);
}
