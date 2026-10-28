import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';

/// The four ways a learner can spend a session on a deck.
enum StudyMode { review, test, match, write }

/// Opens the study-mode chooser and resolves to the picked mode.
///
/// The sheet is the single entry point for every study action: the deck screen
/// only knows about "ادرس", and this file owns the routing decision, so adding
/// a fourth mode later touches one place.
Future<StudyMode?> showStudyModeSheet(
  BuildContext context, {
  required String deckTitle,
  required int cardCount,
  required int dueCount,
}) {
  return showModalBottomSheet<StudyMode>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    isScrollControlled: true,
    useSafeArea: true,
    // The floating tab bar lives in the shell's Stack, and the shell's
    // navigator sits above this sheet: without the root navigator the bar
    // paints over the sheet and hides the last mode. On the root navigator the
    // sheet and its scrim cover the whole screen, which is what a modal is.
    useRootNavigator: true,
    builder: (BuildContext context) => _StudyModeSheet(
      deckTitle: deckTitle,
      cardCount: cardCount,
      dueCount: dueCount,
    ),
  );
}

/// What a session will study: one deck, or everything.
///
/// The two cases share every line of routing below, which is the point — the
/// global queue is not a second study engine, it is the same one with a wider
/// scope id.
///
/// Not marked @immutable: the deck constructor forwards a live DeckNode's
/// fields, which cannot appear in a constant initializer, so the annotation
/// would only buy a lint that cannot be satisfied.
class StudyTarget {
  const StudyTarget({
    required this.scope,
    required this.title,
    required this.cardCount,
    required this.dueCount,
  });

  StudyTarget.deck(DeckNode deck)
    : this(
        scope: deck.id,
        title: deck.title,
        cardCount: deck.cardCount,
        dueCount: deck.dueCount,
      );

  /// Every deck at once, with the totals the home hero already shows.
  StudyTarget.everything({required int cardCount, required int dueCount})
    : this(
        scope: kAllDecksScope,
        title: 'جميع المجموعات',
        cardCount: cardCount,
        dueCount: dueCount,
      );

  final String scope;
  final String title;
  final int cardCount;
  final int dueCount;
}

/// Asks which mode to study [deck] in, then opens it.
///
/// Every "start studying" button in the app goes through here — the deck
/// screen, the home hero and the progress tab. Home used to push the flashcard
/// route directly, so the other three modes were only reachable from inside a
/// deck.
Future<void> openStudyMode(BuildContext context, DeckNode deck) {
  return openStudyTarget(context, StudyTarget.deck(deck));
}

/// Studies every due card in the library, whichever deck it lives in.
Future<void> openGlobalStudy(
  BuildContext context, {
  required int cardCount,
  required int dueCount,
}) {
  return openStudyTarget(
    context,
    StudyTarget.everything(cardCount: cardCount, dueCount: dueCount),
  );
}

Future<void> openStudyTarget(BuildContext context, StudyTarget target) async {
  final StudyMode? mode = await showStudyModeSheet(
    context,
    deckTitle: target.title,
    cardCount: target.cardCount,
    dueCount: target.dueCount,
  );
  if (mode == null || !context.mounted) {
    return;
  }
  switch (mode) {
    case StudyMode.review:
      await context.push('/review/${target.scope}');
    case StudyMode.test:
      await context.push('/test/${target.scope}');
    case StudyMode.match:
      await context.push('/match/${target.scope}');
    case StudyMode.write:
      await context.push('/write/${target.scope}');
  }
}

class _StudyModeSheet extends StatelessWidget {
  const _StudyModeSheet({
    required this.deckTitle,
    required this.cardCount,
    required this.dueCount,
  });

  final String deckTitle;
  final int cardCount;
  final int dueCount;

  bool get _canReview => dueCount > 0;
  bool get _canPlay => cardCount >= 2;
  bool get _canWrite => cardCount >= 1;

  String _reviewSubtitle() {
    if (_canReview) {
      return 'راجع بطاقاتك واحدة تلو الأخرى وقيّم مستواك.';
    }
    return cardCount == 0
        ? 'أضف بطاقات إلى هذه المجموعة أولًا.'
        : 'لا بطاقات مستحقة الآن، عد لاحقًا أو جرّب نمطًا آخر.';
  }

  String _playSubtitle(String fallback) {
    return _canPlay ? fallback : 'تحتاج بطاقتين على الأقل في هذه المجموعة.';
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.6 : 0.24),
              blurRadius: 40,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: context.muted.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SheetHeader(deckTitle: deckTitle),
                const SizedBox(height: 18),
                _ModeCard(
                  icon: CupertinoIcons.rectangle_on_rectangle_angled,
                  title: 'المراجعة',
                  subtitle: _reviewSubtitle(),
                  tint: context.primary,
                  accent: context.accent,
                  enabled: _canReview,
                  badge: _canReview ? '$dueCount مستحقة' : null,
                  delay: 60,
                  onTap: () => Navigator.of(context).pop(StudyMode.review),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  icon: CupertinoIcons.checkmark_seal,
                  title: 'الاختبار',
                  subtitle: _playSubtitle(
                    'اختبر معلوماتك من خلال أسئلة اختيار من متعدد.',
                  ),
                  tint: context.info,
                  accent: Color.lerp(context.info, context.cardSurface, 0.72)!,
                  enabled: _canPlay,
                  badge: null,
                  delay: 140,
                  onTap: () => Navigator.of(context).pop(StudyMode.test),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'المطابقة',
                  subtitle: _playSubtitle(
                    'لعبة سريعة لمطابقة السؤال بالإجابة، وتحدي الوقت.',
                  ),
                  tint: context.danger,
                  accent: Color.lerp(
                    context.danger,
                    context.cardSurface,
                    0.72,
                  )!,
                  enabled: _canPlay,
                  badge: null,
                  delay: 220,
                  onTap: () => Navigator.of(context).pop(StudyMode.match),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  icon: CupertinoIcons.pencil,
                  title: 'وضع الكتابة',
                  subtitle: _canWrite
                      ? 'اكتب الإجابة بنفسك لاختبار حفظك الحقيقي.'
                      : 'تحتاج بطاقة واحدة على الأقل في هذه المجموعة.',
                  tint: context.primary,
                  accent: Color.lerp(
                    context.primary,
                    context.cardSurface,
                    0.72,
                  )!,
                  enabled: _canWrite,
                  badge: null,
                  delay: 300,
                  onTap: () => Navigator.of(context).pop(StudyMode.write),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'اختر النمط الذي يناسب مزاجك الآن',
                    style: TextStyle(
                      color: context.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.deckTitle});

  final String deckTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[context.accent, context.accentDeep],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.accent.withValues(alpha: 0.42),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            CupertinoIcons.sparkles,
            size: 22,
            color: context.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'كيف تحب أن تدرس؟',
                style: TextStyle(
                  color: context.ink,
                  fontFamily: 'ReadexPro',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                deckTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق',
          icon: Icon(CupertinoIcons.xmark, size: 18, color: context.muted),
        ),
      ],
    );
  }
}

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
    required this.enabled,
    required this.delay,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;
  final bool enabled;
  final int delay;
  final String? badge;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!widget.enabled) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool on = widget.enabled;
    final Color ink = on ? context.ink : context.muted.withValues(alpha: 0.75);

    return AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: GestureDetector(
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: _handleTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[
                    widget.tint.withValues(alpha: on ? 0.10 : 0.04),
                    context.cardSurface,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.tint.withValues(alpha: on ? 0.26 : 0.12),
                  width: 1.2,
                ),
                boxShadow: _pressed
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: context.isDark ? 0.35 : 0.05,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: on
                            ? <Color>[
                                widget.accent,
                                Color.lerp(widget.accent, widget.tint, 0.45)!,
                              ]
                            : <Color>[
                                widget.tint.withValues(alpha: 0.18),
                                widget.tint.withValues(alpha: 0.10),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: on
                          ? <BoxShadow>[
                              BoxShadow(
                                color: widget.accent.withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: on
                          ? widget.tint
                          : widget.tint.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  color: ink,
                                  fontFamily: 'ReadexPro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (widget.badge != null) ...<Widget>[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.tint.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  widget.badge!,
                                  style: TextStyle(
                                    color: widget.tint,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: on
                                ? context.muted
                                : context.muted.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_back,
                    size: 15,
                    color: on
                        ? widget.tint.withValues(alpha: 0.55)
                        : context.muted.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 320),
          delay: Duration(milliseconds: widget.delay),
          curve: Curves.easeOut,
        )
        .slideX(
          begin: 0.10,
          end: 0,
          duration: const Duration(milliseconds: 380),
          delay: Duration(milliseconds: widget.delay),
          curve: Curves.easeOutCubic,
        );
  }
}
