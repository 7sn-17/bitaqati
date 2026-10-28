import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/icon_providers.dart';
import '../config/app_config.dart';
import '../dynamic_icon.dart';

/// The colour the native launch screen paints.
///
/// Deliberately not a palette colour: Android draws its own splash before
/// Flutter exists, from a fixed resource, and the two only meet without a
/// flash if they agree. The value is the one in res/values/colors.xml
/// (launch_background). The sheet opens on it and blooms into the chosen
/// icon's field, so the handoff reads as the first frame of the animation.
const Color _launchField = Color(0xFF0B0F0C);

/// The animated launch screen.
///
/// Three things and nothing else: a field that takes the colour of the icon
/// this install is wearing, the icon itself under a breathing halo with a band
/// of light crossing it, and the name. There is no rule, no divider and no
/// border anywhere on this screen — every edge is a gradient, so nothing can
/// read as a line.
class AnimatedSplash extends ConsumerStatefulWidget {
  const AnimatedSplash({required this.child, required this.arabic, super.key});

  /// The app itself, already built. The splash is painted over it.
  final Widget child;

  final bool arabic;

  @override
  ConsumerState<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends ConsumerState<AnimatedSplash> {
  /// When the entrance is over and the sheet starts to fade.
  static const Duration _hold = Duration(milliseconds: 1650);

  static const Duration _fade = Duration(milliseconds: 420);

  bool _fading = false;
  bool _gone = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, () {
      if (mounted) {
        setState(() => _fading = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The splash is the first thing the eye sees, so it has to agree with the
    // launcher: a phone wearing the blue icon used to launch onto the yellow
    // one. One provider, three readers (here, the login screen, the picker).
    final AppIconOption icon = ref.watch(activeIconProvider);

    return Stack(
      children: <Widget>[
        widget.child,
        if (!_gone)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fading,
              child: AnimatedOpacity(
                opacity: _fading ? 0 : 1,
                duration: _fade,
                curve: Curves.easeInCubic,
                onEnd: () {
                  if (_fading && mounted) {
                    setState(() => _gone = true);
                  }
                },
                // The sheet sits above the app, not inside a page, so there
                // is no Scaffold or Material above it: without one, Text falls
                // back to the debug style and draws the yellow double
                // underline. A transparent Material supplies the ancestor and
                // paints nothing.
                child: Material(
                  type: MaterialType.transparency,
                  child: _SplashSheet(arabic: widget.arabic, icon: icon),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashSheet extends StatelessWidget {
  const _SplashSheet({required this.arabic, required this.icon});

  final bool arabic;

  final AppIconOption icon;

  @override
  Widget build(BuildContext context) {
    // The native splash is a flat dark field; tinting it towards the icon's own
    // colour keeps the seam invisible and makes the identity of the app obvious
    // before a single pixel of UI is drawn.
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: _launchField, end: icon.background),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, Color? field, Widget? child) {
        return ColoredBox(color: field ?? _launchField, child: child);
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SplashIcon(icon: icon),
            const SizedBox(height: 38),
            Text(
              arabic ? AppConfig.appNameAr : AppConfig.appNameEn,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.18,
              ),
            ).animate().fadeIn(
              delay: 220.ms,
              duration: 820.ms,
              curve: Curves.easeOut,
            ),
            const SizedBox(height: 14),
            Text(
              arabic
                  ? 'حفظٌ يتجدّد، بطاقةً بعد بطاقة'
                  : 'Memory that renews, one card at a time',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ).animate().fadeIn(
              delay: 700.ms,
              duration: 700.ms,
              curve: Curves.easeOut,
            ),
          ],
        ),
      ),
    );
  }
}

/// The icon, lit.
///
/// One clock drives both the breath and the sweep, so the light always crosses
/// the artwork at the same point in the pulse and the two never drift into
/// looking like separate effects. The sweep is a gradient with soft stops —
/// no mask, no hard edge, nothing that can render as a line.
class _SplashIcon extends StatefulWidget {
  const _SplashIcon({required this.icon});

  final AppIconOption icon;

  @override
  State<_SplashIcon> createState() => _SplashIconState();
}

class _SplashIconState extends State<_SplashIcon>
    with SingleTickerProviderStateMixin {
  static const double _size = 148;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color field = widget.icon.background;
    // A light bloom of the icon's own field: on the navy icon it reads as a
    // cool halo, on the greens as warm light.
    final Color glow = Color.lerp(field, Colors.white, 0.58)!;

    return AnimatedBuilder(
          animation: _clock,
          builder: (BuildContext context, Widget? child) {
            final double breath =
                0.5 + 0.5 * math.sin(_clock.value * 2 * math.pi);
            return Transform.scale(
              scale: 1 + 0.022 * breath,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(42),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: glow.withValues(alpha: 0.30 + 0.14 * breath),
                      blurRadius: 64 + 18 * breath,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: _size,
            height: _size,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(42),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.asset(widget.icon.asset, fit: BoxFit.cover),
                  _Sweep(clock: _clock, size: _size),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.86, 0.86),
          end: const Offset(1, 1),
          duration: 760.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// The band of light that crosses the artwork.
///
/// Built from a gradient whose two ends are fully transparent, so the band has
/// no edge of its own: what moves is brightness, not a shape. It travels from
/// beyond one corner to beyond the other, which is what makes it read as a
/// reflection rather than a wipe.
class _Sweep extends StatelessWidget {
  const _Sweep({required this.clock, required this.size});

  final AnimationController clock;

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: clock,
        builder: (BuildContext context, Widget? child) {
          final double phase = Curves.easeInOutCubic.transform(
            (clock.value + 0.15) % 1,
          );
          // The band is wider than the icon, so its ends are always off-screen.
          final double travel = (phase * 2.4 - 0.7) * size;
          return Transform.translate(
            offset: Offset(travel, travel * 0.55),
            child: Transform.rotate(angle: math.pi / 5.2, child: child),
          );
        },
        child: Container(
          width: size * 0.52,
          height: size * 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.30),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const <double>[0.0, 0.32, 0.5, 0.68, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
