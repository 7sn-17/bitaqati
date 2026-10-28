import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The fixed ink of the mascot illustration.
///
/// The mascot is a character rather than a surface: it keeps its own colours
/// whatever identity the app is wearing, the way a mascot printed on a poster
/// does not change because the room was repainted. Everything around it comes
/// from [PaywallInk], which follows the active theme.
abstract final class PaywallArtInk {
  static const Color ink = Color(0xFF14301F);
  static const Color green = Color(0xFF1E8A3B);
  static const Color yellow = Color(0xFFFFC93C);
  static const Color white = Color(0xFFFFFFFF);
}

/// The paywall's palette, resolved from the active theme.
///
/// The design was drawn against one fixed set of greens. Those values survive
/// as the *relationships* — a page, a card, a deep ink, a bright action colour,
/// a soft wash of it, a highlight — and every one of them is now read from the
/// theme, so the screen wears Forest, Ocean, Sunset or Classic and switches
/// between light and dark without a single hard-coded colour.
///
/// The action colour is [accent] rather than [primary]: a primary button in
/// this app is the bright highlight with deep ink on top, which is what keeps
/// the call to action loud on a near-white canvas and on a near-black one.
@immutable
class PaywallInk {
  const PaywallInk({
    required this.page,
    required this.ink,
    required this.muted,
    required this.green,
    required this.onGreen,
    required this.greenDark,
    required this.border,
    required this.chip,
    required this.yellow,
    required this.onYellow,
    required this.yellowSoft,
    required this.greenSoft,
    required this.radioEmpty,
    required this.heart,
    required this.dangerSoft,
    required this.white,
  });

  factory PaywallInk.of(BuildContext context) {
    return PaywallInk(
      page: context.canvas,
      ink: context.ink,
      muted: context.muted,
      green: context.accent,
      onGreen: context.onAccent,
      greenDark: context.accentDeep,
      border: context.hairline,
      chip: context.softAccent,
      yellow: context.star,
      // [star] is the same gold in every palette, so the ink on top of it is
      // fixed too: it is a badge, not a surface.
      onYellow: const Color(0xFF231A00),
      yellowSoft: context.warningSurface,
      greenSoft: context.accentSoft,
      radioEmpty: context.muted.withValues(alpha: 0.45),
      heart: context.danger,
      dangerSoft: context.danger.withValues(alpha: 0.12),
      white: context.cardSurface,
    );
  }

  /// The page behind everything.
  final Color page;

  /// Primary text.
  final Color ink;

  /// Secondary text and captions.
  final Color muted;

  /// The action colour: buttons, selected radios, prices.
  final Color green;

  /// Text and glyphs drawn on [green].
  final Color onGreen;

  /// One step darker than [green], for the lip under a button.
  final Color greenDark;

  /// Outlines and dividers.
  final Color border;

  /// Neutral pill behind a label.
  final Color chip;

  /// The gold badge.
  final Color yellow;

  /// Ink for anything drawn on [yellow].
  final Color onYellow;

  /// Soft wash behind a warning or a nudge.
  final Color yellowSoft;

  /// Soft wash of the action colour.
  final Color greenSoft;

  /// An unselected control.
  final Color radioEmpty;

  /// Negative feedback.
  final Color heart;

  /// Background for negative feedback.
  final Color dangerSoft;

  /// Card background.
  final Color white;
}

extension PaywallColors on BuildContext {
  /// The paywall palette for this theme.
  PaywallInk get pay => PaywallInk.of(this);
}

/// The design's card treatment: a 2px outline plus a thick coloured lip along
/// the bottom edge, which is what gives the whole screen its toy-like weight.
///
/// Shared with the upgrade dialogs so a prompt opened from a deck list looks
/// like it came from the same product as the paywall it leads to.
BoxDecoration paywallToyBox({
  required Color fill,
  required Color border,
  double radius = 20,
  double lip = 5,
}) {
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: 2),
    boxShadow: <BoxShadow>[
      BoxShadow(color: border, offset: Offset(0, lip), blurRadius: 0),
    ],
  );
}

/// The card mascot: two tilted cards, a face and a sparkle.
///
/// Hand-drawn rather than shipped as an asset so it stays crisp at any size and
/// follows the exact geometry of the design (104 x 104).
class MascotPainter extends CustomPainter {
  const MascotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 104;
    canvas.save();
    canvas.scale(scale, scale);

    final Paint inkPaint = Paint()..color = PaywallArtInk.ink;
    final Paint whitePaint = Paint()..color = PaywallArtInk.white;

    // Back card, tilted left and slightly translucent-looking behind the front.
    canvas.save();
    canvas.translate(47, 54);
    canvas.rotate(-8 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 66, height: 76),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFBFE3C6),
    );
    canvas.restore();

    // Front card.
    canvas.save();
    canvas.translate(55, 50);
    canvas.rotate(6 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 66, height: 76),
        const Radius.circular(16),
      ),
      Paint()..color = PaywallArtInk.yellow,
    );
    canvas.restore();

    // Face. Drawn upright so the expression reads straight, as in the design.
    canvas.drawCircle(const Offset(46, 44), 6.5, inkPaint);
    canvas.drawCircle(const Offset(68, 46), 6.5, inkPaint);
    canvas.drawCircle(const Offset(48, 42), 2, whitePaint);
    canvas.drawCircle(const Offset(70, 44), 2, whitePaint);

    canvas.drawPath(
      Path()
        ..moveTo(48, 58)
        ..cubicTo(53, 65, 62, 66, 68, 59),
      Paint()
        ..color = PaywallArtInk.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    final Paint blush = Paint()
      ..color = const Color(0xFFFF9F7A).withValues(alpha: 0.7);
    canvas.drawCircle(const Offset(39, 56), 4, blush);
    canvas.drawCircle(const Offset(77, 58), 4, blush);

    // Sparkle at the top corner.
    canvas.drawPath(
      Path()
        ..moveTo(90, 10)
        ..lineTo(92, 16)
        ..lineTo(98, 18)
        ..lineTo(92, 20)
        ..lineTo(90, 26)
        ..lineTo(88, 20)
        ..lineTo(82, 18)
        ..lineTo(88, 16)
        ..close(),
      Paint()..color = PaywallArtInk.green,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MascotPainter oldDelegate) => false;
}

/// The illustrated artwork inside a payment-method tile.
///
/// Each one is a 96 x 64 drawing, exactly the viewBox of the design's SVGs.
enum PaywallArt { cash, wallet, crypto }

class PaymentArtPainter extends CustomPainter {
  const PaymentArtPainter(this.art);

  final PaywallArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 96;
    canvas.save();
    canvas.scale(scale, scale);
    switch (art) {
      case PaywallArt.cash:
        _cash(canvas);
      case PaywallArt.wallet:
        _wallet(canvas);
      case PaywallArt.crypto:
        _crypto(canvas);
    }
    canvas.restore();
  }

  void _cash(Canvas canvas) {
    final RRect back = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 4, 82, 46),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      back,
      Paint()..color = const Color(0xFFFFF4CC).withValues(alpha: 0.6),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 12, 84, 46),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFF0B429),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 18, 72, 34),
        const Radius.circular(5),
      ),
      Paint()
        ..color = const Color(0xFFFFF4CC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      const Offset(46, 35),
      11,
      Paint()..color = const Color(0xFFFFF4CC),
    );

    final Paint stroke = Paint()
      ..color = const Color(0xFFF0B429)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(46, 29), const Offset(46, 41), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(42.5, 32.5)
        ..cubicTo(42.5, 30.5, 49.5, 30.5, 49.5, 32.5)
        ..cubicTo(49.5, 34.5, 42.5, 34, 42.5, 36)
        ..cubicTo(42.5, 38, 49.5, 38, 49.5, 36),
      stroke,
    );
  }

  void _wallet(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 2, 32, 60),
        const Radius.circular(7),
      ),
      Paint()..color = PaywallArtInk.green,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 9, 24, 42),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFDFF3E3),
    );
    canvas.drawCircle(
      const Offset(48, 26),
      7,
      Paint()..color = PaywallArtInk.green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(44.5, 26)
        ..lineTo(47, 28.5)
        ..lineTo(51.5, 23.5),
      Paint()
        ..color = const Color(0xFFDFF3E3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 38, 16, 4),
        const Radius.circular(2),
      ),
      Paint()..color = PaywallArtInk.green.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      const Offset(48, 56),
      1.5,
      Paint()..color = const Color(0xFFDFF3E3),
    );

    final Paint waves = Paint()
      ..color = PaywallArtInk.green.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(22, 22)
        ..cubicTo(18, 26, 18, 36, 22, 40),
      waves,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13, 16)
        ..cubicTo(6, 23, 6, 40, 13, 48),
      waves,
    );
    canvas.drawPath(
      Path()
        ..moveTo(74, 22)
        ..cubicTo(78, 26, 78, 36, 74, 40),
      waves,
    );
    canvas.drawPath(
      Path()
        ..moveTo(83, 16)
        ..cubicTo(90, 23, 90, 40, 83, 48),
      waves,
    );
  }

  void _crypto(Canvas canvas) {
    canvas.drawCircle(
      const Offset(34, 38),
      16,
      Paint()..color = const Color(0xFFDCEBFF).withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      const Offset(58, 32),
      24,
      Paint()..color = const Color(0xFF3B82F6),
    );
    canvas.drawCircle(
      const Offset(58, 32),
      18,
      Paint()
        ..color = const Color(0xFFDCEBFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final double cx = 58;
    const double cy = 32;
    final Path hex = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = -math.pi / 2 + i * math.pi / 3;
      final Offset point = Offset(
        cx + 11 * math.cos(angle),
        cy + 11 * math.sin(angle),
      );
      if (i == 0) {
        hex.moveTo(point.dx, point.dy);
      } else {
        hex.lineTo(point.dx, point.dy);
      }
    }
    hex.close();
    canvas.drawPath(hex, Paint()..color = const Color(0xFFDCEBFF));

    canvas.drawPath(
      Path()
        ..moveTo(16, 8)
        ..lineTo(18, 13)
        ..lineTo(23, 15)
        ..lineTo(18, 17)
        ..lineTo(16, 22)
        ..lineTo(14, 17)
        ..lineTo(9, 15)
        ..lineTo(14, 13)
        ..close(),
      Paint()..color = const Color(0xFF3B82F6),
    );
  }

  @override
  bool shouldRepaint(covariant PaymentArtPainter oldDelegate) =>
      oldDelegate.art != art;
}
