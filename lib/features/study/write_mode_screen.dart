import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/card_markup.dart';
import '../../data/content_providers.dart';
import '../../domain/answer_match.dart';
import '../../domain/models.dart';

/// Write mode: the learner types the answer instead of recognising it.
///
/// Recognition is cheap and it is what multiple choice measures; production is
/// the honest test. Every answer is still written through \`recordReview\`, so a
/// correct recall is Good and a miss is Again, exactly like the review screen.
class WriteModeScreen extends ConsumerWidget {
  const WriteModeScreen({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeckNode? deck = ref.watch(deckByIdProvider(deckId));
    final List<ReviewCard>? cards = ref
        .watch(deckCardsProvider(deckId))
        .valueOrNull;
    if (cards == null) {
      return Scaffold(
        backgroundColor: context.isDark
            ? AppColors.darkCanvas
            : AppColors.canvas,
        body: Center(child: CircularProgressIndicator(color: context.brandInk)),
      );
    }
    final List<ReviewCard> usable = <ReviewCard>[
      for (final ReviewCard card in cards)
        if (card.type != 'occlusion' &&
            plainMarkup(card.front).trim().isNotEmpty &&
            plainMarkup(card.back).trim().isNotEmpty)
          card,
    ];
    if (usable.isEmpty) {
      return _NotEnough(deckTitle: deck?.title ?? '');
    }
    return _WriteSession(
      deckTitle: deck?.title ?? 'وضع الكتابة',
      cards: usable,
    );
  }
}

enum _Phase { typing, correct, wrong }

class _WriteSession extends ConsumerStatefulWidget {
  const _WriteSession({required this.deckTitle, required this.cards});

  final String deckTitle;
  final List<ReviewCard> cards;

  @override
  ConsumerState<_WriteSession> createState() => _WriteSessionState();
}

class _WriteSessionState extends ConsumerState<_WriteSession> {
  static const int _maxQuestions = 12;

  late List<ReviewCard> _cards;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  int _index = 0;
  int _correct = 0;
  _Phase _phase = _Phase.typing;
  DateTime _shownAt = DateTime.now();
  Timer? _advanceTimer;
  bool _finished = false;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _cards = List<ReviewCard>.of(widget.cards)..shuffle();
    if (_cards.length > _maxQuestions) {
      _cards = _cards.take(_maxQuestions).toList();
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  ReviewCard get _card => _cards[_index];

  void _check() {
    if (_phase != _Phase.typing) {
      return;
    }
    final String typed = _controller.text.trim();
    if (typed.isEmpty) {
      return;
    }
    final AnswerCheck check = checkAnswer(plainMarkup(_card.back), typed);
    _focus.unfocus();
    setState(() => _phase = check.correct ? _Phase.correct : _Phase.wrong);
    if (!check.correct) {
      unawaited(SoundService.instance.wrong());
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
      return;
    }
    unawaited(SoundService.instance.correct());
    HapticFeedback.heavyImpact();
    _advanceTimer = Timer(
      const Duration(milliseconds: 1150),
      () => _advance(good: true),
    );
  }

  /// Records the answer and moves on. [good] is what the learner deserves
  /// credit for, which is not always what the matcher decided: the override
  /// button exists because a synonym is not a memory failure.
  void _advance({required bool good}) {
    if (_advancing || !mounted) {
      return;
    }
    _advancing = true;
    _advanceTimer?.cancel();

    final ReviewCard card = _card;
    final int elapsed = DateTime.now().difference(_shownAt).inMilliseconds;
    unawaited(
      ref
          .read(contentRepositoryProvider)
          .recordReview(
            cardId: card.id,
            rating: good ? 3 : 1,
            elapsedMs: elapsed,
            allowEarly: true,
          )
          .catchError((Object error) {
            if (!mounted) {
              return;
            }
            showAppMessage(
              context,
              'تعذّر حفظ إجابتك في جدول المراجعة.',
              kind: AppMessageKind.error,
            );
          }),
    );

    if (!mounted) {
      return;
    }
    if (_index + 1 >= _cards.length) {
      setState(() {
        if (good) {
          _correct++;
        }
        _finished = true;
        _advancing = false;
      });
      return;
    }
    setState(() {
      if (good) {
        _correct++;
      }
      _index++;
      _phase = _Phase.typing;
      _controller.clear();
      _shownAt = DateTime.now();
      _advancing = false;
    });
    _focus.requestFocus();
  }

  void _restart() {
    _advanceTimer?.cancel();
    setState(() {
      _cards = List<ReviewCard>.of(widget.cards)..shuffle();
      if (_cards.length > _maxQuestions) {
        _cards = _cards.take(_maxQuestions).toList();
      }
      _index = 0;
      _correct = 0;
      _phase = _Phase.typing;
      _controller.clear();
      _finished = false;
      _advancing = false;
      _shownAt = DateTime.now();
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? AppColors.darkCanvas : AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _finished
              ? _WriteResult(
                  key: const ValueKey<String>('result'),
                  deckTitle: widget.deckTitle,
                  correct: _correct,
                  total: _cards.length,
                  onRetry: _restart,
                  onClose: () => Navigator.of(context).maybePop(),
                )
              : _buildSession(context),
        ),
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final double progress =
        (_index + (_phase == _Phase.typing ? 0 : 1)) / _cards.length;
    return Column(
      key: const ValueKey<String>('session'),
      children: <Widget>[
        _WriteTopBar(
          index: _index,
          total: _cards.length,
          correct: _correct,
          progress: progress,
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              _PromptCard(
                key: ValueKey<int>(_index),
                deckTitle: widget.deckTitle,
                card: _card,
              ),
              const SizedBox(height: 16),
              _AnswerField(
                controller: _controller,
                focus: _focus,
                locked: _phase != _Phase.typing,
                onSubmitted: _check,
              ),
              const SizedBox(height: 14),
              if (_phase == _Phase.typing)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _check,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'ReadexPro',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('تحقّق'),
                  ),
                )
              else
                _Feedback(
                  correct: _phase == _Phase.correct,
                  expected: plainMarkup(_card.back).trim(),
                  typed: _controller.text.trim(),
                  onOverride: () => _advance(good: true),
                  onNext: () => _advance(good: _phase == _Phase.correct),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WriteTopBar extends StatelessWidget {
  const _WriteTopBar({
    required this.index,
    required this.total,
    required this.correct,
    required this.progress,
    required this.onClose,
  });

  final int index;
  final int total;
  final int correct;
  final double progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.raisedSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 17,
                    color: context.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'سؤال ${index + 1} من $total',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اكتب الإجابة كما تتذكرها',
                      style: TextStyle(
                        color: context.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.softAccent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      size: 13,
                      color: context.onSoftAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$correct',
                      style: TextStyle(
                        color: context.onSoftAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Container(color: context.raisedSurface),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double value, Widget? _) {
                      return FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppColors.accent,
                                Color(0xFF63C13A),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.deckTitle, required this.card, super.key});

  final String deckTitle;
  final ReviewCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: context.isDark
              ? <Color>[AppColors.darkSurfaceHigh, AppColors.darkSurface]
              : <Color>[Colors.white, const Color(0xFFF3F7EE)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: context.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: context.softAccent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  deckTitle,
                  style: TextStyle(
                    color: context.onSoftAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(CupertinoIcons.pencil, size: 12, color: context.muted),
              const SizedBox(width: 4),
              Text(
                'السؤال',
                style: TextStyle(
                  color: context.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CardMarkup(
            text: card.front,
            revealCloze: false,
            mediaFirst: true,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 21,
              height: 1.55,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
            mediaHeight: 170,
          ),
        ],
      ),
    );
  }
}

class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.controller,
    required this.focus,
    required this.locked,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool locked;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'إجابتك',
          style: TextStyle(
            color: context.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focus,
          enabled: !locked,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          style: TextStyle(
            fontFamily: 'ReadexPro',
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: context.ink,
          ),
          decoration: InputDecoration(
            hintText: 'اكتب الإجابة هنا…',
            hintStyle: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.muted.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: context.cardSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.brandInk, width: 1.6),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.hairline),
            ),
          ),
        ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.correct,
    required this.expected,
    required this.typed,
    required this.onOverride,
    required this.onNext,
  });

  final bool correct;
  final String expected;
  final String typed;
  final VoidCallback onOverride;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final Color tint = correct ? AppColors.accent : AppColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: context.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                correct
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: correct
                    ? (context.isDark ? AppColors.accent : AppColors.primary)
                    : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'إجابة صحيحة' : 'ليست هذه الإجابة',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: correct
                      ? (context.isDark ? AppColors.accent : AppColors.primary)
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'الإجابة الصحيحة',
            style: TextStyle(
              color: context.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            expected,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
          if (!correct && typed.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'إجابتك: $typed',
              style: TextStyle(
                color: context.muted,
                fontSize: 11.5,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (correct)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'التالي',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOverride,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.ink,
                      side: BorderSide(color: context.hairline),
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'كنت محقاً',
                      style: TextStyle(
                        fontFamily: 'ReadexPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'التالي',
                      style: TextStyle(
                        fontFamily: 'ReadexPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WriteResult extends StatelessWidget {
  const _WriteResult({
    required this.deckTitle,
    required this.correct,
    required this.total,
    required this.onRetry,
    required this.onClose,
    super.key,
  });

  final String deckTitle;
  final int correct;
  final int total;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final double score = total == 0 ? 0 : correct / total;
    final String headline = switch (score) {
      >= 0.9 => 'حفظ متقن',
      >= 0.7 => 'نتيجة قوية',
      >= 0.4 => 'بداية جيدة',
      _ => 'تحتاج مراجعة',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[AppColors.accent, Color(0xFF63C13A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${(score * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '$correct من $total',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            deckTitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.muted, fontSize: 12),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'أعد الاختبار',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.ink,
                side: BorderSide(color: context.hairline),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEnough extends StatelessWidget {
  const _NotEnough({required this.deckTitle});

  final String deckTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? AppColors.darkCanvas : AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.softAccent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    CupertinoIcons.pencil,
                    size: 28,
                    color: context.onSoftAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا بطاقات للكتابة',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'وضع الكتابة يحتاج بطاقة بسؤال وإجابة نصية. '
                  'أضف بطاقة إلى «$deckTitle» ثم عد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.muted,
                    fontSize: 12,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('رجوع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
