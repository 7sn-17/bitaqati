import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/freemium.dart';
import 'paywall_art.dart';
import 'paywall_screen.dart';

/// The prompt shown when the free tier runs out.
///
/// Written as a dialog in the paywall's own visual language rather than a bare
/// AlertDialog: it is the first thing a free learner sees when they hit a
/// ceiling, and it should look like part of the product rather than an error.
Future<void> _showUpgrade({
  required BuildContext context,
  required FaIconData icon,
  required String title,
  required String message,
  required String reason,
  String action = 'ترقية إلى Pro',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: paywallToyBox(
            fill: context.pay.white,
            border: context.pay.border,
            radius: 26,
            lip: 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.pay.yellowSoft,
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, size: 26, color: context.pay.green),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.pay.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.75,
                  color: context.pay.muted,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    openPaywall(context, reason: reason);
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.pay.green,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: context.pay.greenDark,
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.pay.onGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'لاحقاً',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.pay.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The ceiling on decks.
///
/// [lapsed] changes the wording: someone whose subscription just ended is not
/// being sold to, they are being told which 25 decks stayed open.
Future<void> showDeckLimitDialog(BuildContext context, {required bool lapsed}) {
  final int limit = FreeLimits.decksFor(everPro: lapsed);
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.layerGroup,
    title: 'وصلت إلى $limit مجموعة',
    message: lapsed
        ? 'بعد انتهاء اشتراكك أبقينا أحدث $limit مجموعة مفتوحة، والبقية محفوظة كما هي بلا حذف. '
              'جدّد Pro لتعود كل المجموعات للعمل.'
        : 'الخطة المجانية تتسع لـ$limit مجموعة. مجموعاتك الحالية محفوظة، '
              'وPro يرفع الحد بلا نهاية.',
    reason: lapsed
        ? 'أبقينا $limit مجموعة مفتوحة بعد انتهاء اشتراكك. جدّد لتعود كلها.'
        : 'وصلت إلى حد $limit مجموعة في الخطة المجانية.',
  );
}

/// Opened when someone taps a deck the free tier has frozen.
Future<void> showFrozenDeckDialog(
  BuildContext context, {
  required String deckTitle,
}) {
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.lock,
    title: 'هذه المجموعة مجمّدة',
    message:
        '«$deckTitle» محفوظة بكل بطاقاتها ومواعيد مراجعتها، لكنها خارج المجموعات المفتوحة. '
        'لا شيء حُذف: الترقية تعيدها للعمل فوراً.',
    reason: 'مجموعة «$deckTitle» مجمّدة. Pro يفتح كل مجموعاتك.',
    action: 'افتح كل المجموعات',
  );
}

/// Opened when a free account taps a palette other than Forest.
Future<void> showThemeLockedDialog(BuildContext context) {
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.palette,
    title: 'الثيمات لمشتركي Pro',
    message:
        'الخطة المجانية تعمل بثيم الغابة. Pro يفتح المحيط والغروب والكلاسيكي، '
        'ويطبّقها على كل شاشة في التطبيق.',
    reason: 'الثيمات الملونة متاحة مع Pro.',
    action: 'افتح الثيمات',
  );
}

/// Opened when a free account taps one of the paid launcher icons.
Future<void> showIconLockedDialog(BuildContext context) {
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.crown,
    title: 'أيقونات التطبيق لمشتركي Pro',
    message:
        'بدّل أيقونة بطاقتي على شاشتك الرئيسية: الافتراضية، التاج، أو الأزرق. '
        'متاح مع Pro.',
    reason: 'أيقونات التطبيق متاحة مع Pro.',
    action: 'افتح الأيقونات',
  );
}

/// The prompt for every ceiling except decks.
///
/// The wording lives on [QuotaKind] so the same numbers appear in the paywall
/// table, in this dialog and in the guard that raised it.
Future<void> showQuotaDialog(BuildContext context, QuotaKind kind) {
  return _showUpgrade(
    context: context,
    icon: switch (kind) {
      QuotaKind.cards => FontAwesomeIcons.layerGroup,
      QuotaKind.occlusion => FontAwesomeIcons.objectGroup,
      QuotaKind.cloze => FontAwesomeIcons.textWidth,
      QuotaKind.images => FontAwesomeIcons.image,
      QuotaKind.audio => FontAwesomeIcons.microphone,
      QuotaKind.importCards => FontAwesomeIcons.fileImport,
      QuotaKind.studySessions => FontAwesomeIcons.graduationCap,
    },
    title: kind.title,
    message: kind.message,
    reason: kind.reason,
  );
}
