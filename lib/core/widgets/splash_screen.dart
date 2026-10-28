import 'dart:async';
import 'dart:ui' show ImageFilter;

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
/// Sits above the router for the first moment of the process: the field takes
/// the colour of the icon this install is wearing, the icon lands with a short
/// overshoot under a glow, the name slides in from the right while it sharpens,
/// and the tagline follows. It is a cover, not a route, so nothing in the
/// navigation stack knows it happened and a deep link that arrives during it
/// still lands on the right screen.
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
  static const Duration _hold = Duration(milliseconds: 1500);

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
                child: _SplashSheet(arabic: widget.arabic, icon: icon),
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
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, Color? field, Widget? child) {
        return ColoredBox(color: field ?? _launchField, child: child);
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: <BoxShadow>[
                      // A light bloom of the icon's own field: on the navy icon
                      // it reads as a cool halo, on the greens as warm light.
                      BoxShadow(
                        color: Color.lerp(
                          icon.background,
                          Colors.white,
                          0.55,
                        )!.withValues(alpha: 0.42),
                        blurRadius: 46,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(icon.asset, fit: BoxFit.cover),
                )
                // The overshoot is what makes it feel like the icon was
                // placed rather than switched on.
                .animate()
                .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.68, 0.68),
                  end: const Offset(1, 1),
                  duration: 700.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 26),
            _SplashName(
              text: arabic ? AppConfig.appNameAr : AppConfig.appNameEn,
            ),
            const SizedBox(height: 8),
            Text(
                  arabic
                      ? 'حفظٌ يتجدّد، بطاقةً بعد بطاقة'
                      : 'Memory that renews, one card at a time',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                )
                .animate()
                .fadeIn(delay: 620.ms, duration: 460.ms)
                .slideY(
                  begin: 0.4,
                  end: 0,
                  delay: 620.ms,
                  duration: 520.ms,
                  curve: Curves.easeOutCubic,
                ),
          ],
        ),
      ),
    );
  }
}

/// The app name: in from the right, out of focus into sharp.
///
/// The blur is a plain [ImageFilter] driven by a tween rather than an
/// animation package effect — it is the one part of the entrance that has to
/// resolve over a different span than the slide, and two independent clocks
/// express that more honestly than one curve with a delay bolted on.
class _SplashName extends StatelessWidget {
  const _SplashName({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 8, end: 0),
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double sigma, Widget? child) {
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child:
          Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              )
              .animate()
              .fadeIn(delay: 260.ms, duration: 420.ms)
              .slideX(
                begin: 0.32,
                end: 0,
                delay: 260.ms,
                duration: 620.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }
}
