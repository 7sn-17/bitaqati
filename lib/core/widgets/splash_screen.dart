import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_config.dart';

/// The green the native launch screen paints.
///
/// Deliberately not a palette colour: Android draws its own splash before
/// Flutter exists, from a fixed resource, and the two only meet without a
/// flash if they agree. The value is the one in res/values/colors.xml
/// (launch_background), so the handoff is invisible whatever theme the app
/// is about to open in.
const Color _splashField = Color(0xFF163300);

/// The animated launch screen.
///
/// Sits above the router for the first moment of the process: the icon lands
/// with a short overshoot, the name rises under it, the tagline follows, and
/// the whole sheet fades out onto the first real frame. It is a cover, not a
/// route, so nothing in the navigation stack knows it happened and a deep
/// link that arrives during it still lands on the right screen.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({required this.child, required this.arabic, super.key});

  /// The app itself, already built. The splash is painted over it.
  final Widget child;

  final bool arabic;

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> {
  /// When the entrance is over and the sheet starts to fade.
  static const Duration _hold = Duration(milliseconds: 1450);

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
                child: _SplashSheet(arabic: widget.arabic),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashSheet extends StatelessWidget {
  const _SplashSheet({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _splashField,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/app_icons/default.png',
                    fit: BoxFit.cover,
                  ),
                )
                // The overshoot is what makes it feel like the icon was
                // placed rather than switched on.
                .animate()
                .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.74, 0.74),
                  end: const Offset(1, 1),
                  duration: 620.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 26),
            Text(
                  arabic ? AppConfig.appNameAr : AppConfig.appNameEn,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 420.ms)
                .slideY(
                  begin: 0.35,
                  end: 0,
                  delay: 300.ms,
                  duration: 520.ms,
                  curve: Curves.easeOutCubic,
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
            ).animate().fadeIn(delay: 520.ms, duration: 460.ms),
          ],
        ),
      ),
    );
  }
}
