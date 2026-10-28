import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/freemium.dart';
import 'paywall_art.dart';
import 'paywall_screen.dart';

/// What a frozen deck shows instead of its study screen.
///
/// A frozen deck is not an error state and not an empty deck: its cards are
/// still there and still scheduled. The screen therefore says exactly that —
/// nothing was deleted — and offers the one action that unfreezes it. It is
/// reached from a deep link, a restored route, or a study mode that was already
/// open when the subscription lapsed, so it stands on its own rather than
/// assuming the deck list is behind it.
class FrozenDeckScreen extends StatelessWidget {
  const FrozenDeckScreen({required this.deckTitle, super.key});

  final String deckTitle;

  @override
  Widget build(BuildContext context) {
    return _Wall(
      title: 'هذه المجموعة مجمّدة',
      subtitle: deckTitle,
      message:
          'بطاقاتك وتقدّمك محفوظان بالكامل. المجموعات الأقدم تُقفل عند انتهاء '
          'الاشتراك بدل أن تُحذف، وتعود للعمل فور تجديد Pro.',
      action: 'افتحها مع Pro',
      reason:
          'مجموعة "$deckTitle" مجمّدة. جدّد Pro لفتحها ومتابعة المراجعة '
          'من حيث توقفت.',
    );
  }
}

/// What a free account sees when a session-level ceiling is reached.
///
/// The same wall as a frozen deck, worded from [QuotaKind] so the number in the
/// message is the number the guard actually enforced. Reached from the study
/// screen and the progress tab, both of which have nowhere useful to go
/// without it.
class QuotaWallScreen extends StatelessWidget {
  const QuotaWallScreen({required this.kind, this.subtitle, super.key});

  final QuotaKind kind;

  /// An extra line under the title, usually the deck being studied.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _Wall(
      title: kind.title,
      subtitle: subtitle,
      message: kind.message,
      action: 'افتحها مع Pro',
      reason: kind.reason,
    );
  }
}

class _Wall extends StatelessWidget {
  const _Wall({
    required this.title,
    required this.message,
    required this.action,
    required this.reason,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String message;
  final String action;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pay.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _LockedMascot(),
                const SizedBox(height: 26),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.pay.ink,
                    height: 1.35,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.pay.greenInk,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: paywallToyBox(
                    fill: context.pay.white,
                    border: context.pay.border,
                    radius: 18,
                    lip: 4,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: context.pay.muted,
                      height: 1.85,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _Primary(
                  onPressed: () => openPaywall(context, reason: reason),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FaIcon(
                        FontAwesomeIcons.crown,
                        size: 15,
                        color: context.pay.onGreen,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        action,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.pay.onGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'رجوع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.pay.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mascot with a padlock on its corner: the same character the paywall
/// uses, so the two screens read as one flow.
class _LockedMascot extends StatelessWidget {
  const _LockedMascot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 112,
            height: 112,
            decoration: paywallToyBox(
              fill: context.pay.yellowSoft,
              border: context.pay.yellow,
              radius: 28,
              lip: 5,
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CustomPaint(painter: MascotPainter()),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 0,
            child: Container(
              width: 46,
              height: 46,
              decoration: paywallToyBox(
                fill: context.pay.green,
                border: context.pay.greenDark,
                radius: 15,
                lip: 4,
              ),
              child: FaIcon(
                FontAwesomeIcons.lock,
                size: 17,
                color: context.pay.onGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The paywall's call-to-action shape: 18px radius, the 5px lip, the same
/// green. Kept local rather than shared because the paywall's button carries a
/// loading state and this one has nothing to load.
class _Primary extends StatelessWidget {
  const _Primary({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(color: context.pay.greenDark, offset: const Offset(0, 5)),
          ],
        ),
        child: Material(
          color: context.pay.green,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
