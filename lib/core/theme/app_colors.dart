import 'package:flutter/material.dart';

/// Brand palette extracted from the original design.
abstract final class AppColors {
  static const Color primary = Color(0xFF163300);
  static const Color primaryDeep = Color(0xFF054D28);
  static const Color accent = Color(0xFF9FE870);
  static const Color accentSoft = Color(0xFFE2F6D5);
  static const Color canvas = Color(0xFFFAF9F5);
  static const Color surface = Color(0xFFE8EBE6);
  static const Color ink = Color(0xFF0E0F0C);
  static const Color muted = Color(0xFF6A6C6A);
  static const Color line = Color(0xFFDDE2D8);
  static const Color blue = Color(0xFF0B4C72);
  static const Color danger = Color(0xFFCB272F);
  static const Color warning = Color(0xFFFFF4D6);
  static const Color warningInk = Color(0xFF7A5300);

  // Dark palette. The steps between canvas, surface and surface-high are
  // wide enough that cards and sheets stay distinct from the page.
  static const Color darkCanvas = Color(0xFF0A0E09);
  static const Color darkSurface = Color(0xFF1F2B1D);
  static const Color darkSurfaceHigh = Color(0xFF2C3B2A);
  static const Color darkInk = Color(0xFFF2F5EE);
  static const Color darkMuted = Color(0xFFB3BCAD);
  static const Color darkLine = Color(0xFF42523E);

  /// Background of the review card once the answer is revealed. Lighter than
  /// [primary] so the card separates from the green page behind it.
  static const Color answerSurface = Color(0xFF2B5A1A);
}
