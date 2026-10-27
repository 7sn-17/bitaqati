import 'dart:math';

import 'package:flutter/material.dart';

/// A one-shot particle burst drawn over whatever is behind it.
///
/// Written by hand instead of pulling in a package: the whole effect is one
/// painter and one controller, and it lets the colours match the app instead
/// of a rainbow preset.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    this.pieces = 90,
    this.duration = const Duration(milliseconds: 2600),
    this.colors = const <Color>[
      Color(0xFF9FE870),
      Color(0xFF163300),
      Color(0xFF0B4C72),
      Color(0xFFFFC845),
      Color(0xFFC13584),
    ],
    super.key,
  });

  final int pieces;
  final Duration duration;
  final List<Color> colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final List<_Piece> _pieces = _build();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Piece> _build() {
    final Random random = Random(7);
    return <_Piece>[
      for (int index = 0; index < widget.pieces; index++)
        _Piece(
          x: 0.5 + (random.nextDouble() - 0.5) * 0.28,
          velocity: 260 + random.nextDouble() * 420,
          angle: -pi / 2 + (random.nextDouble() - 0.5) * 1.9,
          spin: (random.nextDouble() - 0.5) * 12,
          size: 5 + random.nextDouble() * 7,
          delay: random.nextDouble() * 0.18,
          color: widget.colors[index % widget.colors.length],
          round: random.nextBool(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _ConfettiPainter(
            pieces: _pieces,
            progress: _controller.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.velocity,
    required this.angle,
    required this.spin,
    required this.size,
    required this.delay,
    required this.color,
    required this.round,
  });

  final double x;
  final double velocity;
  final double angle;
  final double spin;
  final double size;
  final double delay;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.progress});

  final List<_Piece> pieces;
  final double progress;

  static const double _gravity = 980;

  @override
  void paint(Canvas canvas, Size size) {
    final double originY = size.height * 0.28;
    for (final _Piece piece in pieces) {
      final double local = ((progress - piece.delay) / (1 - piece.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) {
        continue;
      }
      final double seconds = local * 2.6;
      final double dx =
          cos(piece.angle) * piece.velocity * seconds * 0.55 +
          sin(seconds * 3 + piece.spin) * 14;
      final double dy =
          sin(piece.angle) * piece.velocity * seconds +
          0.5 * _gravity * seconds * seconds;
      final double x = size.width * piece.x + dx;
      final double y = originY + dy;
      if (y > size.height + 40 || x < -40 || x > size.width + 40) {
        continue;
      }
      final double fade = local < 0.82 ? 1 : (1 - local) / 0.18;
      final Paint paint = Paint()
        ..color = piece.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * seconds * 1.6);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size * 0.42, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size * 0.55,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
