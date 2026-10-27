import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The live scene that sits inside the onboarding illustration card.
///
/// The static SVGs are gone: each slide now animates the *content* of the
/// card -- a flashcard flips to its answer, a note splits into cards, a shelf
/// of decks fills up -- so the picture is doing something instead of drifting
/// as a whole.
class OnboardingScene extends StatefulWidget {
  const OnboardingScene({required this.index, super.key});

  final int index;

  @override
  State<OnboardingScene> createState() => _OnboardingSceneState();
}

class _OnboardingSceneState extends State<OnboardingScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A slice of the master timeline, eased. [begin]/[end] are 0..1.
  double _slice(double t, double begin, double end, {Curve? curve}) {
    final double local = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    return (curve ?? Curves.easeOutCubic).transform(local);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        return switch (widget.index) {
          0 => _reviewScene(context, t),
          1 => _createScene(context, t),
          _ => _libraryScene(context, t),
        };
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 1: a card flips over, the answer lands with a tick.
  // ---------------------------------------------------------------------------
  Widget _reviewScene(BuildContext context, double t) {
    final double flip = _slice(t, 0.28, 0.56, curve: Curves.easeInOutCubic);
    final double angle = flip * math.pi;
    final bool showBack = angle > math.pi / 2;
    final double tick = _slice(t, 0.58, 0.74, curve: Curves.elasticOut);
    final double ring = _slice(t, 0.62, 0.95, curve: Curves.easeOutCubic);

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        for (int i = 2; i >= 1; i--)
          Transform.translate(
            offset: Offset(0, 10.0 * i),
            child: Transform.scale(
              scale: 1 - 0.07 * i,
              child: _MiniCard(
                width: 186,
                height: 116,
                opacity: 0.30 - 0.1 * i,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        Transform.translate(
          offset: Offset(0, -4 + math.sin(t * math.pi * 2) * 2.5),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateX(showBack ? math.pi : 0),
              child: _MiniCard(
                width: 196,
                height: 124,
                child: showBack
                    ? _AnswerFace(progress: tick)
                    : const _QuestionFace(),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 6,
          child: Opacity(
            opacity: ring == 0 ? 0 : 1,
            child: _Ring(progress: ring),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 2: a note slides in, splits into two cards, gets a tick.
  // ---------------------------------------------------------------------------
  Widget _createScene(BuildContext context, double t) {
    final double noteIn = _slice(t, 0.0, 0.22);
    final double split = _slice(t, 0.24, 0.58, curve: Curves.easeOutBack);
    final double tick = _slice(t, 0.6, 0.78, curve: Curves.elasticOut);

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        for (int i = 0; i < 2; i++)
          Transform.translate(
            offset: Offset((i == 0 ? -1 : 1) * 74 * split, 26 * split - 6),
            child: Transform.rotate(
              angle: (i == 0 ? -1 : 1) * 0.09 * split,
              child: Opacity(
                opacity: split.clamp(0.0, 1.0),
                child: _MiniCard(
                  width: 92,
                  height: 112,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Bar(width: 40 + i * 6, color: context.brandInk),
                        const SizedBox(height: 6),
                        const _Bar(width: 62, height: 4),
                        const SizedBox(height: 4),
                        const _Bar(width: 48, height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Transform.translate(
          offset: Offset(0, -34 * noteIn - 6),
          child: Opacity(
            opacity: (1 - split * 0.85).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - 0.12 * split,
              child: _MiniCard(
                width: 150,
                height: 96,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      _Bar(width: 70, height: 5),
                      SizedBox(height: 7),
                      _Bar(width: 104, height: 4),
                      SizedBox(height: 5),
                      _Bar(width: 88, height: 4),
                      SizedBox(height: 5),
                      _Bar(width: 58, height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 6,
          child: Transform.scale(scale: tick, child: const _Tick()),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 3: a shelf of decks fills up, then a rating badge pops.
  // ---------------------------------------------------------------------------
  Widget _libraryScene(BuildContext context, double t) {
    final double star = _slice(t, 0.62, 0.8, curve: Curves.elasticOut);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < 4; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  16 * (1 - _slice(t, 0.05 * i, 0.28 + 0.05 * i)),
                ),
                child: Opacity(
                  opacity: _slice(t, 0.05 * i, 0.24 + 0.05 * i),
                  child: _ShelfTile(index: i),
                ),
              ),
          ],
        ),
        Positioned(
          top: 0,
          right: 4,
          child: Transform.scale(
            scale: star,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(99),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text(
                    '4.8',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionFace extends StatelessWidget {
  const _QuestionFace();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.help_outline_rounded,
                size: 13,
                color: context.brandInk,
              ),
              const SizedBox(width: 4),
              _Bar(width: 34, height: 5, color: context.brandInk),
            ],
          ),
          const SizedBox(height: 10),
          const _Bar(width: 148, height: 7),
          const SizedBox(height: 6),
          const _Bar(width: 112, height: 7),
        ],
      ),
    );
  }
}

class _AnswerFace extends StatelessWidget {
  const _AnswerFace({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Transform.scale(
            scale: progress.clamp(0.0, 1.4),
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 17,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _Bar(width: 120, height: 7, color: AppColors.primary),
          const SizedBox(height: 6),
          const _Bar(width: 86, height: 7, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final int percent = (progress * 92).round();
    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: _RingPainter(progress),
        child: Center(
          child: Text(
            '$percent%',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: context.brandInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = AppColors.primary.withValues(alpha: 0.10),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 21,
        color: AppColors.primary,
      ),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const List<Color> tints = <Color>[
      AppColors.primary,
      AppColors.blue,
      AppColors.primaryDeep,
      AppColors.danger,
    ];
    final Color tint = tints[index % tints.length];
    return Container(
      width: 74,
      height: 60,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.style_rounded, size: 11, color: tint),
          ),
          const Spacer(),
          const _Bar(width: 40, height: 4),
          const SizedBox(height: 3),
          const _Bar(width: 26, height: 3),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.width,
    required this.height,
    required this.child,
    this.opacity = 1,
  });

  final double width;
  final double height;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.hairline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.4 : 0.07,
              ),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A text placeholder line.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, this.height = 6, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: (color ?? context.muted).withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
