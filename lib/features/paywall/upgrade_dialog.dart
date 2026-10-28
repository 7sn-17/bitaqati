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
  required String reason,
  String action = 'ترقية الآن',
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
          child: ConstrainedBox(
            // Three paragraphs and two buttons do not fit on a small phone in
            // landscape. The body scrolls; the buttons never move.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: SingleChildScrollView(
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
                          child: FaIcon(
                            icon,
                            size: 26,
                            color: context.pay.greenInk,
                          ),
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
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          decoration: BoxDecoration(
                            color: context.pay.selectedFill,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'هذه الميزة متاحة لمشتركي النسخة الاحترافية. '
                            'اشتراكك لا يفتح لك ميزات لا نهائية فحسب، بل يساعدنا '
                            'على استمرار تطبيق بطاقاتنا مجاناً للطلاب الذين لا '
                            'يستطيعون الدفع. شكراً لدعمك!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              height: 1.9,
                              fontWeight: FontWeight.w600,
                              color: context.pay.selectedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
        ),
      );
    },
  );
}

/// The ceiling on decks.
///
/// [lapsed] changes the wording: someone whose subscription just ended is not
/// being sold to, they are being told which decks stayed open. [total] is the
/// size of the library, because a lapsed allowance is half of it.
Future<void> showDeckLimitDialog(
  BuildContext context, {
  required bool lapsed,
  required int total,
}) {
  final int limit = lapsed ? FreeLimits.unlockedFor(total) : FreeLimits.decks;
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.layerGroup,
    title: 'وصلت إلى $limit مجموعة',
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
    reason: 'مجموعة «$deckTitle» مجمّدة. Pro يفتح كل مجموعاتك.',
  );
}

/// Opened when a free account taps a palette other than Forest.
Future<void> showThemeLockedDialog(BuildContext context) {
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.palette,
    title: 'الثيمات لمشتركي Pro',
    reason: 'الثيمات الملونة متاحة مع Pro.',
  );
}

/// Opened when a free account taps one of the paid launcher icons.
Future<void> showIconLockedDialog(BuildContext context) {
  return _showUpgrade(
    context: context,
    icon: FontAwesomeIcons.crown,
    title: 'أيقونات التطبيق لمشتركي Pro',
    reason: 'أيقونات التطبيق متاحة مع Pro.',
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
    reason: kind.reason,
  );
}
