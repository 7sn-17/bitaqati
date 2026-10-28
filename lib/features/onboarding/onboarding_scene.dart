import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The live scene that sits inside the onboarding illustration card.
///
/// Each slide animates the *content* of its card rather than the card itself:
/// a flashcard turns over onto its answer, a sentence gets a blank filled in,
/// a shelf of decks fills up, and the four study modes take turns in the light.
/// Everything is drawn in the theme's own colours — no fixed greens, no
/// placeholder grey bars — so a scene reads as part of the product in Forest,
/// Ocean, Sunset and Classic, light or dark.
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
    duration: const Duration(milliseconds: 5600),
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
          2 => _libraryScene(context, t),
          _ => _modesScene(context, t),
        };
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 1: a card turns over onto its answer while the mastery ring fills.
  // ---------------------------------------------------------------------------
  Widget _reviewScene(BuildContext context, double t) {
    final double flip = _slice(t, 0.26, 0.54, curve: Curves.easeInOutCubic);
    final double angle = flip * math.pi;
    final bool showBack = angle > math.pi / 2;
    final double ring = _slice(t, 0.56, 0.94, curve: Curves.easeOutCubic);
    final double tick = _slice(t, 0.58, 0.74, curve: Curves.elasticOut);
    final double float = math.sin(t * math.pi * 2) * 4;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        _Halo(color: context.accent, size: 244, strength: 0.55),
        Transform.translate(
          offset: const Offset(0, 28),
          child: Transform.rotate(
            angle: -0.11,
            child: _BlankCard(width: 184, height: 116, opacity: 0.35),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 15),
          child: Transform.rotate(
            angle: 0.075,
            child: _BlankCard(width: 198, height: 124, opacity: 0.62),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -4 + float),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0013)
              ..rotateX(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateX(showBack ? math.pi : 0),
              child: _FlipCard(showBack: showBack, tick: tick),
            ),
          ),
        ),
        Positioned(top: 2, right: 12, child: _Ring(progress: ring)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 2: a sentence gets a blank, the blank fills, the card is saved.
  // ---------------------------------------------------------------------------
  Widget _createScene(BuildContext context, double t) {
    final double pop = _slice(t, 0.0, 0.2, curve: Curves.easeOutBack);
    final double fill = _slice(t, 0.34, 0.6, curve: Curves.easeOutCubic);
    final double tick = _slice(t, 0.62, 0.8, curve: Curves.elasticOut);
    final double drift = math.sin(t * math.pi * 2) * 3;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        _Halo(color: context.accent, size: 236, strength: 0.5),
        Transform.translate(
          offset: Offset(0, drift),
          child: Transform.scale(
            scale: 0.94 + 0.06 * pop,
            child: Opacity(
              opacity: pop.clamp(0.0, 1.0),
              child: _Composer(fill: fill),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          left: 16,
          child: Transform.scale(scale: tick, child: const _Tick()),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 3: four decks arrive on a shelf, then the rating lands.
  // ---------------------------------------------------------------------------
  Widget _libraryScene(BuildContext context, double t) {
    final double star = _slice(t, 0.6, 0.78, curve: Curves.elasticOut);
    const List<({IconData icon, String label, int cards})> decks =
        <({IconData icon, String label, int cards})>[
          (icon: Icons.science_rounded, label: 'الفيزياء', cards: 240),
          (icon: Icons.translate_rounded, label: 'الإنجليزية', cards: 512),
          (icon: Icons.history_edu_rounded, label: 'التاريخ', cards: 180),
          (icon: Icons.code_rounded, label: 'البرمجة', cards: 320),
        ];
    final List<Color> tints = <Color>[
      context.info,
      context.accent,
      context.danger,
      context.brandInk,
    ];

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        _Halo(color: context.accent, size: 230, strength: 0.42),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < decks.length; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  18 * (1 - _slice(t, 0.05 * i, 0.3 + 0.05 * i)),
                ),
                child: Opacity(
                  opacity: _slice(t, 0.05 * i, 0.26 + 0.05 * i),
                  child: _DeckTile(
                    icon: decks[i].icon,
                    label: decks[i].label,
                    cards: decks[i].cards,
                    tint: tints[i],
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          top: 0,
          left: 4,
          child: Transform.scale(scale: star, child: const _RatingBadge()),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 4: the four study modes, taking turns in the light.
  // ---------------------------------------------------------------------------
  Widget _modesScene(BuildContext context, double t) {
    const List<({IconData icon, String label})> modes =
        <({IconData icon, String label})>[
          (icon: Icons.style_rounded, label: 'بطاقات'),
          (icon: Icons.quiz_rounded, label: 'اختبار'),
          (icon: Icons.grid_view_rounded, label: 'مطابقة'),
          (icon: Icons.edit_rounded, label: 'كتابة'),
        ];
    // A spotlight that travels from tile to tile and then rests a beat on the
    // last one, so the eye follows all four instead of landing on a favourite.
    final double phase = (t * 4.4) % 4;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        _Halo(color: context.accent, size: 236, strength: 0.45),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < modes.length; i++)
              _ModeTile(
                icon: modes[i].icon,
                label: modes[i].label,
                lit: (1 - (phase - i).abs()).clamp(0.0, 1.0),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- primitives

/// The soft light behind a scene. A radial gradient, so it has no edge.
class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size, this.strength = 0.5});

  final Color color;

  final double size;

  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.22 * strength),
              color.withValues(alpha: 0.06 * strength),
              color.withValues(alpha: 0),
            ],
            stops: const <double>[0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

/// The surface every card in these scenes is cut from: a soft gradient, a
/// hairline that only exists in dark mode, and two shadows — a wide ambient one
/// and a tight contact one, which is what makes a flat rectangle read as a
/// physical card.
BoxDecoration _surface(BuildContext context, {double radius = 22}) {
  final bool dark = context.isDark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color.alphaBlend(
          Colors.white.withValues(alpha: dark ? 0.04 : 0.0),
          context.cardSurface,
        ),
        Color.alphaBlend(
          context.primary.withValues(alpha: dark ? 0.12 : 0.05),
          context.cardSurface,
        ),
      ],
    ),
    border: Border.all(
      color: context.hairline.withValues(alpha: dark ? 0.9 : 1),
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.45 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.28 : 0.04),
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

TextStyle _titleStyle(BuildContext context) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  height: 1.5,
  color: context.ink,
);

TextStyle _bodyStyle(BuildContext context) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  height: 1.8,
  color: context.ink,
);

TextStyle _captionStyle(BuildContext context) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 9,
  fontWeight: FontWeight.w600,
  height: 1.4,
  color: context.muted,
);

/// A small label with a glyph, used for tags and categories.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.softAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 10, color: context.brandInk),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: context.brandInk,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with nothing on it, for the stack behind the hero.
class _BlankCard extends StatelessWidget {
  const _BlankCard({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;

  final double height;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: _surface(context),
      ),
    );
  }
}

// --------------------------------------------------------------------- slide 1

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.showBack, required this.tick});

  final bool showBack;

  final double tick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      height: 134,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _surface(context),
      child: showBack ? _answer(context) : _question(context),
    );
  }

  Widget _question(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _Tag(icon: Icons.science_rounded, label: 'علوم'),
            const Spacer(),
            Text('٣ من ١٢', style: _captionStyle(context)),
          ],
        ),
        const Spacer(),
        Text('ما عاصمة اليابان؟', style: _titleStyle(context)),
        const SizedBox(height: 6),
        Text('اقلب البطاقة لترى الإجابة', style: _captionStyle(context)),
      ],
    );
  }

  Widget _answer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Transform.scale(
              scale: tick.clamp(0.0, 1.25),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: context.onAccent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('طوكيو', style: _titleStyle(context)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'عاصمة اليابان وأكبر مدنها، ويقطنها نحو ١٤ مليون نسمة.',
          style: _captionStyle(context),
        ),
        const Spacer(),
        Row(
          children: <Widget>[
            Icon(Icons.bolt_rounded, size: 12, color: context.brandInk),
            const SizedBox(width: 3),
            Text('تذكّر ٩٢٪', style: _captionStyle(context)),
          ],
        ),
      ],
    );
  }
}

/// The mastery ring: an arc that fills as the answer lands.
class _Ring extends StatelessWidget {
  const _Ring({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final int percent = (progress * 92).round();
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          track: context.primary.withValues(alpha: 0.10),
          color: context.accent,
        ),
        child: Center(
          child: Text(
            '$percent٪',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
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
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;

  /// Unfilled part of the ring. Passed in because a painter has no context.
  final Color track;

  /// Filled part of the ring.
  final Color color;

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
        ..color = track,
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
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.accent,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.accent.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, size: 22, color: context.onAccent),
    );
  }
}

// --------------------------------------------------------------------- slide 2

class _Composer extends StatelessWidget {
  const _Composer({required this.fill});

  /// 0 leaves the blank empty, 1 fills it with the answer.
  final double fill;

  @override
  Widget build(BuildContext context) {
    final double word = ((fill - 0.35) / 0.65).clamp(0.0, 1.0);
    return Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: _surface(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _ModePill(
                icon: Icons.style_rounded,
                label: 'أساسية',
                active: true,
              ),
              const SizedBox(width: 6),
              const _ModePill(icon: Icons.data_object_rounded, label: 'فراغ'),
              const SizedBox(width: 6),
              const _ModePill(icon: Icons.image_outlined, label: 'صورة'),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'الخلية هي وحدة بناء '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        context.hairline.withValues(alpha: 0.5),
                        context.accent,
                        fill,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Opacity(
                      opacity: word,
                      child: Text(
                        'الكائن الحي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.6,
                          color: context.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '، وأصغر وحدة قادرة على الحياة.'),
              ],
            ),
            style: _bodyStyle(context),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const _Tag(icon: Icons.lightbulb_outline_rounded, label: 'تلميح'),
              const SizedBox(width: 6),
              const _Tag(icon: Icons.sell_outlined, label: 'أحياء'),
              const Spacer(),
              Text('حفظ', style: _captionStyle(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;

  final String label;

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: active ? context.accent : context.softAccent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 10,
            color: active ? context.onAccent : context.brandInk,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: active ? context.onAccent : context.brandInk,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- slide 3

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.icon,
    required this.label,
    required this.cards,
    required this.tint,
  });

  final IconData icon;

  final String label;

  final int cards;

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 78,
      decoration: _surface(context, radius: 17),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  tint.withValues(alpha: 0.92),
                  Color.lerp(tint, Colors.black, 0.28) ?? tint,
                ],
              ),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: context.ink,
                    ),
                  ),
                  Text('$cards بطاقة', style: _captionStyle(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.accent,
        borderRadius: BorderRadius.circular(99),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.accent.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.star_rounded, size: 12, color: context.onAccent),
          const SizedBox(width: 3),
          Text(
            '٤.٨',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: context.onAccent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- slide 4

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.icon, required this.label, required this.lit});

  final IconData icon;

  final String label;

  /// 0 is at rest, 1 is the mode the light is on right now.
  final double lit;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1 + 0.045 * lit,
      child: Container(
        width: 104,
        height: 82,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.alphaBlend(
                context.accent.withValues(alpha: 0.10 + 0.24 * lit),
                context.cardSurface,
              ),
              Color.alphaBlend(
                context.primary.withValues(alpha: context.isDark ? 0.14 : 0.05),
                context.cardSurface,
              ),
            ],
          ),
          border: Border.all(
            color: Color.lerp(context.hairline, context.accent, lit)!,
            width: 1 + 0.6 * lit,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.4 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
            if (lit > 0.05)
              BoxShadow(
                color: context.accent.withValues(alpha: 0.32 * lit),
                blurRadius: 26 * lit,
                spreadRadius: 1.5,
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color.lerp(
                  context.softAccent,
                  context.accent,
                  lit * 0.85,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 17,
                color: Color.lerp(
                  context.brandInk,
                  context.onAccent,
                  lit * 0.85,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: context.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
