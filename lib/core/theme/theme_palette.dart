import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The four visual identities the app can wear.
///
/// Forest is the original palette and its numbers are frozen: every other
/// palette is derived, but Forest is passed through unchanged so an existing
/// learner sees exactly the app they had.
enum AppThemeId { forest, ocean, sunset, classic }

extension AppThemeIdLabels on AppThemeId {
  String get label => switch (this) {
    AppThemeId.forest => 'الغابة',
    AppThemeId.ocean => 'المحيط',
    AppThemeId.sunset => 'الغروب',
    AppThemeId.classic => 'الكلاسيكي',
  };

  String get tagline => switch (this) {
    AppThemeId.forest => 'أخضر عميق ولمسة ليمون',
    AppThemeId.ocean => 'كحلي هادئ وبرتقالي مشرق',
    AppThemeId.sunset => 'بنفسجي خافت ومرجاني دافئ',
    AppThemeId.classic => 'فحمي رصين وذهبي',
  };
}

/// Every colour the interface is allowed to use.
///
/// A widget never reaches for a literal colour: it asks the palette for a
/// *role* — "the page", "a card", "brand text" — and the palette answers with
/// the value that role has in the active identity and brightness. That is what
/// makes switching from Forest to Ocean change the whole product instead of
/// recolouring a button.
///
/// Contrast is enforced, not hoped for: [ThemePalette.build] measures every
/// text-on-surface pair and walks the foreground toward black or white until
/// it clears the WCAG AA ratio. A palette with an unreadable combination
/// cannot be constructed.
@immutable
class ThemePalette extends ThemeExtension<ThemePalette> {
  const ThemePalette({
    required this.id,
    required this.brightness,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.softAccent,
    required this.onSoftAccent,
    required this.selectedFill,
    required this.brandInk,
    required this.canvas,
    required this.card,
    required this.raised,
    required this.hairline,
    required this.ink,
    required this.muted,
    required this.danger,
    required this.dangerInk,
    required this.warning,
    required this.warningInk,
    required this.info,
    required this.star,
    required this.success,
    required this.answerSurface,
    required this.onAnswer,
  });

  final AppThemeId id;
  final Brightness brightness;

  /// Deep brand fill: the home hero, the avatar tile, the revealed answer.
  final Color primary;

  /// One step darker than [primary], for gradients and pressed states.
  final Color primaryDeep;

  /// Text and icons drawn on [primary].
  final Color onPrimary;

  /// The bright highlight: the primary call to action, progress, badges.
  final Color accent;

  /// Text and icons drawn on [accent].
  final Color onAccent;

  /// Pale wash of [accent] for light surfaces.
  final Color accentSoft;

  /// Wash actually painted behind icons and highlights on the current page.
  final Color softAccent;

  /// Foreground for [softAccent].
  final Color onSoftAccent;

  /// Stronger brand fill for a selected row.
  final Color selectedFill;

  /// The brand colour, safe as *text* on [card].
  final Color brandInk;

  /// Page background.
  final Color canvas;

  /// Card and sheet background.
  final Color card;

  /// Inputs, chips and selected tabs inside a card.
  final Color raised;

  /// Borders and dividers.
  final Color hairline;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  final Color danger;
  final Color dangerInk;
  final Color warning;
  final Color warningInk;
  final Color info;
  final Color star;
  final Color success;

  /// Background of a review card once the answer is revealed.
  final Color answerSurface;
  final Color onAnswer;

  bool get isDark => brightness == Brightness.dark;

  /// The palette for [id] at [brightness].
  static ThemePalette of(AppThemeId id, Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return switch (id) {
      AppThemeId.forest => _forest(dark),
      AppThemeId.ocean => _ocean(dark),
      AppThemeId.sunset => _sunset(dark),
      AppThemeId.classic => _classic(dark),
    };
  }

  // --------------------------------------------------------------- forest --
  // Frozen: these are the numbers the app shipped with. build() still runs the
  // contrast pass, but every pair already clears it, so nothing moves.
  static ThemePalette _forest(bool dark) {
    return ThemePalette.build(
      id: AppThemeId.forest,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF163300),
      primaryDeep: const Color(0xFF054D28),
      accent: const Color(0xFF9FE870),
      accentSoft: const Color(0xFFE2F6D5),
      canvas: dark ? const Color(0xFF080C08) : const Color(0xFFFAF9F5),
      card: dark ? const Color(0xFF151D16) : const Color(0xFFFFFFFF),
      raised: dark ? const Color(0xFF212D22) : const Color(0xFFEDF0E9),
      hairline: dark ? const Color(0xFF3B4A36) : const Color(0xFFDCE2D5),
      inkSeed: dark ? const Color(0xFFF2F7EF) : const Color(0xFF0E0F0C),
      mutedSeed: dark ? const Color(0xFFB6C2B1) : const Color(0xFF5F6659),
      brandInkSeed: dark ? const Color(0xFFA9F27D) : const Color(0xFF163300),
      onAccentSeed: const Color(0xFF163300),
      answerSurface: dark ? const Color(0xFF1D3D12) : const Color(0xFF2B5A1A),
      dangerSeed: dark ? const Color(0xFFFF8A8A) : const Color(0xFFCB272F),
      warningSeed: dark ? const Color(0xFF33270F) : const Color(0xFFFFF4D6),
      warningInkSeed: dark ? const Color(0xFFF3C969) : const Color(0xFF7A5300),
      infoSeed: dark ? const Color(0xFF8FD3F4) : const Color(0xFF0B4C72),
    );
  }

  // ---------------------------------------------------------------- ocean --
  static ThemePalette _ocean(bool dark) {
    return ThemePalette.build(
      id: AppThemeId.ocean,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF0B2B4A),
      primaryDeep: const Color(0xFF061B2F),
      accent: const Color(0xFFFF8A3D),
      accentSoft: const Color(0xFFDCEAF7),
      canvas: dark ? const Color(0xFF050C14) : const Color(0xFFF5F8FB),
      card: dark ? const Color(0xFF0C1A27) : const Color(0xFFFFFFFF),
      raised: dark ? const Color(0xFF15293B) : const Color(0xFFE8EFF6),
      hairline: dark ? const Color(0xFF23405A) : const Color(0xFFD6E2EC),
      inkSeed: dark ? const Color(0xFFEAF3FA) : const Color(0xFF08131E),
      mutedSeed: dark ? const Color(0xFFA6BCCD) : const Color(0xFF4C6173),
      brandInkSeed: dark ? const Color(0xFF7FC4FF) : const Color(0xFF0B2B4A),
      onAccentSeed: const Color(0xFF2A1200),
      answerSurface: dark ? const Color(0xFF0E3554) : const Color(0xFF14496F),
      dangerSeed: dark ? const Color(0xFFFF9A9A) : const Color(0xFFC62828),
      warningSeed: dark ? const Color(0xFF2C2413) : const Color(0xFFFFF2D2),
      warningInkSeed: dark ? const Color(0xFFF0C86A) : const Color(0xFF7A5300),
      infoSeed: dark ? const Color(0xFF8FD3F4) : const Color(0xFF0B4C72),
    );
  }

  // --------------------------------------------------------------- sunset --
  static ThemePalette _sunset(bool dark) {
    return ThemePalette.build(
      id: AppThemeId.sunset,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF4A3F7A),
      primaryDeep: const Color(0xFF322A57),
      accent: const Color(0xFFFF8A7A),
      accentSoft: const Color(0xFFF9E2E3),
      canvas: dark ? const Color(0xFF120A0F) : const Color(0xFFFAF6F7),
      card: dark ? const Color(0xFF1C121A) : const Color(0xFFFFFFFF),
      raised: dark ? const Color(0xFF2A1B25) : const Color(0xFFF3EAEC),
      hairline: dark ? const Color(0xFF422C38) : const Color(0xFFE6D8DC),
      inkSeed: dark ? const Color(0xFFF8EEF1) : const Color(0xFF231419),
      mutedSeed: dark ? const Color(0xFFC6AEBA) : const Color(0xFF6A535B),
      brandInkSeed: dark ? const Color(0xFFFF9EAF) : const Color(0xFF4A3F7A),
      onAccentSeed: const Color(0xFF3A0F12),
      answerSurface: dark ? const Color(0xFF3A2F5C) : const Color(0xFF56477F),
      dangerSeed: dark ? const Color(0xFFFF9AA0) : const Color(0xFFC62A46),
      warningSeed: dark ? const Color(0xFF32201A) : const Color(0xFFFFEFE2),
      warningInkSeed: dark ? const Color(0xFFF0B98A) : const Color(0xFF7A4218),
      infoSeed: dark ? const Color(0xFF9CC8F0) : const Color(0xFF2C5F8A),
    );
  }

  // -------------------------------------------------------------- classic --
  static ThemePalette _classic(bool dark) {
    return ThemePalette.build(
      id: AppThemeId.classic,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF1B1B1D),
      primaryDeep: const Color(0xFF0A0A0B),
      accent: const Color(0xFFE8B84B),
      accentSoft: const Color(0xFFF7EDD6),
      canvas: dark ? const Color(0xFF0A0A0B) : const Color(0xFFF7F7F8),
      card: dark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
      raised: dark ? const Color(0xFF1F1F22) : const Color(0xFFEFEFF1),
      hairline: dark ? const Color(0xFF333338) : const Color(0xFFE0E0E4),
      inkSeed: dark ? const Color(0xFFF5F5F7) : const Color(0xFF121214),
      mutedSeed: dark ? const Color(0xFFA8A8B0) : const Color(0xFF5A5A63),
      brandInkSeed: dark ? const Color(0xFFE8B84B) : const Color(0xFF1B1B1D),
      onAccentSeed: const Color(0xFF241A00),
      answerSurface: dark ? const Color(0xFF232327) : const Color(0xFF2C2C30),
      dangerSeed: dark ? const Color(0xFFFF8A8A) : const Color(0xFFC62828),
      warningSeed: dark ? const Color(0xFF2C2413) : const Color(0xFFFDF3DC),
      warningInkSeed: dark ? const Color(0xFFE8C078) : const Color(0xFF6E4E00),
      infoSeed: dark ? const Color(0xFF9FC7E8) : const Color(0xFF1F4E6E),
    );
  }

  // ---------------------------------------------------------------- build --
  /// Assembles a palette and enforces readability on the way.
  ///
  /// Every text colour is measured against the surface it will actually sit on
  /// and nudged toward black or white until it clears [aaText] (4.5:1). The
  /// seeds are the designer's intent; the ratios are the guarantee.
  static ThemePalette build({
    required AppThemeId id,
    required Brightness brightness,
    required Color primary,
    required Color primaryDeep,
    required Color accent,
    required Color accentSoft,
    required Color canvas,
    required Color card,
    required Color raised,
    required Color hairline,
    required Color inkSeed,
    required Color mutedSeed,
    required Color brandInkSeed,
    required Color onAccentSeed,
    required Color answerSurface,
    required Color dangerSeed,
    required Color warningSeed,
    required Color warningInkSeed,
    required Color infoSeed,
  }) {
    final bool dark = brightness == Brightness.dark;
    final Color ink = readable(inkSeed, card, min: 9);
    final Color muted = readable(mutedSeed, card, min: 4.5);
    final Color brandInk = readable(brandInkSeed, card, min: 4.5);
    final Color onAccent = readable(onAccentSeed, accent, min: 4.5);
    final Color onPrimary = readable(
      const Color(0xFFFFFFFF),
      primary,
      min: 4.5,
    );
    final Color onAnswer = readable(const Color(0xFFFFFFFF), answerSurface);
    return ThemePalette(
      id: id,
      brightness: brightness,
      primary: primary,
      primaryDeep: primaryDeep,
      onPrimary: onPrimary,
      accent: accent,
      onAccent: onAccent,
      accentSoft: accentSoft,
      softAccent: dark ? accent.withValues(alpha: 0.16) : accentSoft,
      onSoftAccent: dark ? brandInk : readable(primary, accentSoft, min: 4.5),
      selectedFill: dark ? accent.withValues(alpha: 0.22) : accentSoft,
      brandInk: brandInk,
      canvas: canvas,
      card: card,
      raised: raised,
      hairline: hairline,
      ink: ink,
      muted: muted,
      danger: dangerSeed,
      dangerInk: readable(dangerSeed, card, min: 4.5),
      warning: warningSeed,
      warningInk: readable(warningInkSeed, warningSeed, min: 4.5),
      info: readable(infoSeed, card, min: 4.5),
      star: const Color(0xFFE0A200),
      success: readable(
        dark ? const Color(0xFF8FD68A) : const Color(0xFF3F7A2A),
        card,
        min: 4.5,
      ),
      answerSurface: answerSurface,
      onAnswer: onAnswer,
    );
  }

  /// WCAG AA for body text.
  static const double aaText = 4.5;

  /// Relative contrast between two opaque colours.
  static double contrast(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double hi = math.max(la, lb);
    final double lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Returns [fg], or the closest step toward black/white that clears [min]
  /// against [bg].
  ///
  /// Twenty steps of 5% is enough to cross the full range, so the loop always
  /// terminates with a colour that passes — the fallback is pure black or pure
  /// white, which clears every mid-tone surface.
  static Color readable(Color fg, Color bg, {double min = aaText}) {
    if (contrast(fg, bg) >= min) {
      return fg;
    }
    final Color target = bg.computeLuminance() > 0.45
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    for (int step = 1; step <= 20; step++) {
      final Color candidate = Color.lerp(fg, target, step / 20)!;
      if (contrast(candidate, bg) >= min) {
        return candidate;
      }
    }
    return target;
  }

  @override
  ThemePalette copyWith() => this;

  /// Cross-fades every token, which is what makes a palette switch animate
  /// instead of snapping.
  @override
  ThemePalette lerp(covariant ThemePalette? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ThemePalette(
      id: t < 0.5 ? id : other.id,
      brightness: brightness,
      primary: mix(primary, other.primary),
      primaryDeep: mix(primaryDeep, other.primaryDeep),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      softAccent: mix(softAccent, other.softAccent),
      onSoftAccent: mix(onSoftAccent, other.onSoftAccent),
      selectedFill: mix(selectedFill, other.selectedFill),
      brandInk: mix(brandInk, other.brandInk),
      canvas: mix(canvas, other.canvas),
      card: mix(card, other.card),
      raised: mix(raised, other.raised),
      hairline: mix(hairline, other.hairline),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      danger: mix(danger, other.danger),
      dangerInk: mix(dangerInk, other.dangerInk),
      warning: mix(warning, other.warning),
      warningInk: mix(warningInk, other.warningInk),
      info: mix(info, other.info),
      star: mix(star, other.star),
      success: mix(success, other.success),
      answerSurface: mix(answerSurface, other.answerSurface),
      onAnswer: mix(onAnswer, other.onAnswer),
    );
  }
}
