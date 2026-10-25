import 'package:flutter/material.dart';

abstract final class AppColors {
  // --- Original Brand Palette ---
  static const Color lime = Color(0xFFC9F56D);
  static const Color limeDeep = Color(0xFFA8D94E);
  static const Color forest = Color(0xFF163300);
  static const Color mint = Color(0xFF8FD8B2);
  static const Color lavender = Color(0xFFBDB7FF);
  static const Color amber = Color(0xFFF6C86B);
  static const Color coral = Color(0xFFFF8F7E);
  static const Color sky = Color(0xFF7FC8F8);

  // --- Light Theme Surfaces ---
  static const Color canvas = Color(0xFFF6F7F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF1E8);
  static const Color ink = Color(0xFF151A13);
  static const Color muted = Color(0xFF6B7568);
  static const Color line = Color(0xFFE1E5DA);

  // --- Dark Theme Surfaces ---
  static const Color darkCanvas = Color(0xFF0B0E0B);
  static const Color darkSurface = Color(0xFF141914);
  static const Color darkSurfaceHigh = Color(0xFF1D241D);
  static const Color darkSurfaceHighest = Color(0xFF263026);
  static const Color darkInk = Color(0xFFF2F6ED);
  static const Color darkMuted = Color(0xFFA0AC9F);
  static const Color darkLine = Color(0xFF2C352C);

  // --- Semantic Aliases (Added to fix UI errors) ---
  // These map to the existing palette so the UI works seamlessly.
  static const Color primary = forest;
  static const Color primaryDeep = Color(0xFF0D1F00);
  static const Color accent = lime;
  static const Color accentSoft = Color(0xFFE5FCC2);
  static const Color danger = coral;
  static const Color warning = amber;
  static const Color warningInk = Color(0xFF5C4011);

  static const List<Color> deckPalette = <Color>[
    Color(0xFF1D6FD1),
    Color(0xFF0B7A5A),
    Color(0xFF3B7A1F),
    Color(0xFFA65A3A),
    Color(0xFF6B5BC9),
    Color(0xFFC25B8A),
    Color(0xFFB07A1D),
    Color(0xFF2C7E86),
  ];

  static Color fromHex(String hex) {
    final String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(0xFF000000 | int.parse(clean, radix: 16));
    }
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return deckPalette.first;
  }

  static Color tint(Color color, {required bool isDark}) {
    return isDark
        ? Color.alphaBlend(color.withValues(alpha: 0.18), darkSurface)
        : Color.alphaBlend(color.withValues(alpha: 0.12), surface);
  }
}
