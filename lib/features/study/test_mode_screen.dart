import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/card_markup.dart';
import '../../core/widgets/confetti_burst.dart';
import '../../data/content_providers.dart';
import '../paywall/frozen_deck_screen.dart';
import '../../domain/models.dart';

/// Multiple-choice test built from a deck.
///
/// The screen is deliberately self-contained: it reads the deck once, freezes
/// the question list, and then never touches the database again. That keeps the
/// session fast and makes "أعد الاختبار" a pure in-memory rebuild.
class TestModeScreen extends ConsumerWidget {
  const TestModeScreen({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeckNode? deck = ref.watch(deckByIdProvider(deckId));
    // A frozen deck keeps its cards but hands out no session. Checked before
    // the card stream so the screen never flashes an empty-deck message.
    if (deck != null && deck.frozen) {
      return FrozenDeckScreen(deckTitle: deck.title);
    }
    final List<ReviewCard>? cards = ref
        .watch(studyCardsProvider(deckId))
        .valueOrNull;
    if (cards == null) {
      // A white flash while the cards load is the most jarring thing a dark-
      // mode user can hit on this screen, so the loading state follows the
      // theme like everything else.
      return Scaffold(
        backgroundColor: context.canvas,
        body: Center(child: CircularProgressIndicator(color: context.brandInk)),
      );
    }
    // The queue is built from pieces, not cards: a cloze sentence and an
    // occlusion picture both split into several questions. Two pieces are the
    // floor because a single one has no wrong answer to offer.
    final List<_Fragment> pieces = _buildFragments(cards);
    if (pieces.length < 2) {
      return _NotEnough(deckTitle: deck?.title ?? 'جميع المجموعات');
    }
    return _TestSession(
      deckId: deckId,
      deckTitle: deck?.title ?? 'جميع المجموعات',
      pieces: pieces,
    );
  }
}

enum _QuestionKind { choice, trueFalse }

class _Question {
  const _Question({
    required this.card,
    required this.prompt,
    required this.options,
    required this.correct,
    this.kind = _QuestionKind.choice,
    this.candidate = '',
    this.maskIndex,
  });

  final ReviewCard card;

  /// The question side, already prepared for this piece: a cloze sentence with
  /// only this blank hidden, or the shared prompt of an occlusion card.
  final String prompt;

  final List<String> options;
  final int correct;
  final _QuestionKind kind;

  /// For a true/false question: the answer the learner is judging. Empty for a
  /// multiple-choice question.
  final String candidate;

  /// Which plate of an occlusion card this question is about, so the picture
  /// can ring the region being asked about. Null for every other card type.
  final int? maskIndex;
}

/// One answerable piece of a card.
///
/// A plain card is a single piece. A cloze card is one piece per blank and an
/// occlusion card is one piece per mask, so a four-mask picture becomes four
/// questions. Every piece keeps the id of the card it came from: that is what
/// lets the queue space siblings apart and pick wrong answers from other cards
/// instead of from the same picture.
class _Fragment {
  const _Fragment({
    required this.card,
    required this.prompt,
    required this.answer,
    required this.key,
    this.maskIndex,
  });

  final ReviewCard card;
  final String prompt;
  final String answer;

  /// Unique per card and per piece. A piece is only ever added once per
  /// session, so the same mask can never be asked twice in a row.
  final String key;

  final int? maskIndex;

  String get cardId => card.id;
}

/// Rewrites a cloze sentence so only the blank at [target] stays hidden and
/// every other blank is spelled out. Without this, four questions about one
/// sentence would all look identical.
String _clozePrompt(String front, int target) {
  int index = 0;
  return front.replaceAllMapped(kClozeRegex, (Match match) {
    final int slot = index++;
    final String answer = (match.group(1) ?? '').trim();
    if (slot != target) {
      return answer;
    }
    return '▁' * (answer.length.clamp(2, 12).toInt());
  });
}

/// Every piece the deck can be asked about, in card order.
///
/// Pieces with no answer are dropped: an occlusion mask the writer never filled
/// in cannot be graded, and a blank with nothing inside it is not a question.
List<_Fragment> _buildFragments(List<ReviewCard> cards) {
  final List<_Fragment> pieces = <_Fragment>[];
  final Set<String> seen = <String>{};
  void add(_Fragment piece) {
    if (piece.answer.isEmpty) {
      return;
    }
    if (!seen.add(piece.key)) {
      return;
    }
    pieces.add(piece);
  }

  for (final ReviewCard card in cards) {
    final int before = pieces.length;
    if (card.type == 'occlusion') {
      final List<OcclusionBox> boxes = occlusionBoxes(card.occlusion);
      final String prompt = occlusionPrompt(card.back);
      for (int index = 0; index < boxes.length; index++) {
        add(
          _Fragment(
            card: card,
            prompt: prompt,
            answer: boxes[index].answer.trim(),
            key: '${card.id}#mask$index',
            maskIndex: index,
          ),
        );
      }
    } else if (card.type == 'cloze') {
      final List<RegExpMatch> blanks = kClozeRegex
          .allMatches(card.front)
          .toList(growable: false);
      for (int index = 0; index < blanks.length; index++) {
        add(
          _Fragment(
            card: card,
            prompt: _clozePrompt(card.front, index),
            answer: (blanks[index].group(1) ?? '').trim(),
            key: '${card.id}#blank$index',
          ),
        );
      }
    }
    if (pieces.length > before) {
      continue;
    }
    // A card that has no usable piece — an occlusion picture whose masks were
    // never labelled, or a cloze sentence with every blank left empty — still
    // has two sides worth testing, so it is asked as a whole card instead of
    // being dropped from the session.
    add(
      _Fragment(
        card: card,
        prompt: card.front,
        answer: plainMarkup(card.back).trim(),
        key: '${card.id}#card',
      ),
    );
  }
  return pieces;
}

/// Spreads pieces so two of the same card never sit side by side.
///
/// One shuffled bucket per card, then a round-robin pass over the buckets: every
/// pass takes at most one piece from each card, so a card's pieces end up as far
/// apart as the deck allows. When one card owns more pieces than the rest of the
/// deck together, the surplus at the tail cannot be separated and stays as is —
/// which is the best a single-picture deck can do.
List<_Fragment> _interleave(
  List<_Fragment> pool,
  math.Random random,
  int limit,
) {
  final Map<String, List<_Fragment>> buckets = <String, List<_Fragment>>{};
  for (final _Fragment piece in pool) {
    buckets.putIfAbsent(piece.cardId, () => <_Fragment>[]).add(piece);
  }
  final List<String> cards = buckets.keys.toList()..shuffle(random);
  for (final List<_Fragment> group in buckets.values) {
    group.shuffle(random);
  }
  final List<_Fragment> queue = <_Fragment>[];
  String? previous;
  while (queue.length < limit) {
    final List<String> open = <String>[
      for (final String cardId in cards)
        if (buckets[cardId]!.isNotEmpty) cardId,
    ];
    if (open.isEmpty) {
      break;
    }
    // Never the same card twice in a row while another card still has pieces;
    // when only one card is left there is nothing else to place.
    final List<String> allowed = <String>[
      for (final String cardId in open)
        if (cardId != previous) cardId,
    ];
    final List<String> candidates = allowed.isEmpty ? open : allowed;
    // The card with the most pieces left goes next, so the surplus is spent
    // evenly instead of piling up at the end. Ties are broken by a reshuffle,
    // which keeps the order from being the same every session.
    candidates.shuffle(random);
    String pick = candidates.first;
    for (final String cardId in candidates) {
      if (buckets[cardId]!.length > buckets[pick]!.length) {
        pick = cardId;
      }
    }
    queue.add(buckets[pick]!.removeAt(0));
    previous = pick;
  }
  return queue;
}

List<_Question> _buildQuestions(List<_Fragment> pieces) {
  final math.Random random = math.Random();
  final int count = math.min(10, pieces.length);
  final List<_Fragment> queue = _interleave(
    List<_Fragment>.of(pieces),
    random,
    count,
  );
  final List<_Question> questions = <_Question>[];
  for (final _Fragment piece in queue) {
    final String answer = piece.answer;
    // Wrong answers come from other cards first, so a question about one mask
    // is not answerable by remembering its siblings. A single-card deck has no
    // other card to borrow from; only then are its own pieces used, which is
    // what keeps a four-mask picture testable at all.
    final List<String> foreign = <String>{
      for (final _Fragment other in pieces)
        if (other.cardId != piece.cardId && other.answer != answer)
          other.answer,
    }.toList()..shuffle(random);
    final List<String> siblings = <String>{
      for (final _Fragment other in pieces)
        if (other.cardId == piece.cardId && other.answer != answer)
          other.answer,
    }.toList()..shuffle(random);
    final List<String> others = <String>[...foreign, ...siblings];
    if (others.isEmpty) {
      continue;
    }
    // Roughly a third of the questions are a statement to judge instead of
    // four options to pick. It breaks the rhythm of a session and it tests the
    // pair in the other direction: the learner has to recognise the answer
    // rather than recall it.
    if (random.nextDouble() < 0.35) {
      final bool isTrue = random.nextBool();
      questions.add(
        _Question(
          card: piece.card,
          prompt: piece.prompt,
          options: const <String>['صحيح', 'خطأ'],
          correct: isTrue ? 0 : 1,
          kind: _QuestionKind.trueFalse,
          candidate: isTrue ? answer : others.first,
          maskIndex: piece.maskIndex,
        ),
      );
      continue;
    }
    final List<String> options = <String>[answer, ...others.take(3)]
      ..shuffle(random);
    questions.add(
      _Question(
        card: piece.card,
        prompt: piece.prompt,
        options: options,
        correct: options.indexOf(answer),
        maskIndex: piece.maskIndex,
      ),
    );
  }
  return questions;
}

class _TestSession extends ConsumerStatefulWidget {
  const _TestSession({
    required this.deckId,
    required this.deckTitle,
    required this.pieces,
  });

  final String deckId;
  final String deckTitle;

  /// Everything this deck can be asked about, frozen for the session.
  final List<_Fragment> pieces;

  @override
  ConsumerState<_TestSession> createState() => _TestSessionState();
}

class _TestSessionState extends ConsumerState<_TestSession> {
  late List<_Question> _questions = _buildQuestions(widget.pieces);
  Timer? _advance;
  int _index = 0;
  int _correct = 0;
  int? _picked;
  bool _finished = false;

  /// When the current question appeared, so the answer carries a real latency
  /// into FSRS instead of a guess.
  DateTime _shownAt = DateTime.now();

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  bool get _answered => _picked != null;

  void _choose(int option) {
    if (_answered) {
      return;
    }
    final _Question question = _questions[_index];
    final bool right = option == question.correct;
    setState(() {
      _picked = option;
      if (right) {
        _correct++;
      }
    });
    // Sound and touch together: a right answer chimes and lands heavy, a wrong
    // one buzzes low and fires the longest haptic the platform offers. Medium
    // was indistinguishable from a tab switch in the hand.
    if (right) {
      unawaited(SoundService.instance.correct());
      HapticFeedback.heavyImpact();
    } else {
      unawaited(SoundService.instance.wrong());
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    }
    // A test answer is genuine evidence about memory, so it moves the card's
    // FSRS schedule: right is Good, wrong is Again. It is written off the
    // frame so the next question is never delayed by the database.
    unawaited(
      ref
          .read(contentRepositoryProvider)
          .recordReview(
            cardId: question.card.id,
            rating: right ? 3 : 1,
            elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds,
            allowEarly: true,
          )
          .catchError((Object error) {
            if (!mounted) {
              return;
            }
            showAppMessage(
              context,
              'تعذّر حفظ نتيجة السؤال في جدول المراجعة.',
              kind: AppMessageKind.error,
            );
          }),
    );
    _advance = Timer(const Duration(milliseconds: 980), _next);
  }

  void _next() {
    if (!mounted) {
      return;
    }
    if (_index + 1 >= _questions.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _shownAt = DateTime.now();
    });
  }

  void _restart() {
    _advance?.cancel();
    setState(() {
      _questions = _buildQuestions(widget.pieces);
      _index = 0;
      _correct = 0;
      _picked = null;
      _finished = false;
      _shownAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _finished
        ? 1
        : (_index + (_answered ? 1 : 0)) / _questions.length;

    return Scaffold(
      backgroundColor: (context.canvas),
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _finished
              ? _ResultView(
                  key: const ValueKey<String>('result'),
                  deckTitle: widget.deckTitle,
                  correct: _correct,
                  total: _questions.length,
                  onRetry: _restart,
                  onClose: () => Navigator.of(context).maybePop(),
                )
              : Column(
                  key: const ValueKey<String>('session'),
                  children: <Widget>[
                    _SessionBar(
                      progress: progress,
                      index: _index,
                      total: _questions.length,
                      correct: _correct,
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              final Animation<Offset> slide =
                                  Tween<Offset>(
                                    begin: const Offset(-0.08, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  );
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                        child: _QuestionView(
                          key: ValueKey<int>(_index),
                          question: _questions[_index],
                          deckTitle: widget.deckTitle,
                          position: _index + 1,
                          total: _questions.length,
                          picked: _picked,
                          onPick: _choose,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.progress,
    required this.index,
    required this.total,
    required this.correct,
    required this.onClose,
  });

  final double progress;
  final int index;
  final int total;
  final int correct;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(
                icon: CupertinoIcons.xmark,
                label: 'إغلاق',
                onTap: onClose,
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
                      'اختر الإجابة الصحيحة',
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                context.accent,
                                context.accentDeep,
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

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.deckTitle,
    required this.position,
    required this.total,
    required this.picked,
    required this.onPick,
    super.key,
  });

  final _Question question;
  final String deckTitle;
  final int position;
  final int total;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    const List<String> letters = <String>['أ', 'ب', 'ج', 'د'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[context.cardSurface, context.raisedSurface],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: context.hairline),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDark ? 0.35 : 0.05,
                    ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
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
                      Text(
                        '$position / $total',
                        style: TextStyle(
                          color: context.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (question.card.type == 'occlusion')
                    OcclusionView(
                      imageUrl: occlusionImageUrl(question.card.front),
                      boxes: occlusionBoxes(question.card.occlusion),
                      masked: true,
                      // The plate this question asks about is ringed, so four
                      // questions about one picture never look the same.
                      focus: question.maskIndex,
                      height: 190,
                    )
                  else
                    CardMarkup(
                      // The prompt already hides exactly the blank being
                      // asked about, and spells the other ones out.
                      text: question.prompt,
                      revealCloze: true,
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
            )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(
              begin: 0.06,
              end: 0,
              duration: 380.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 18),
        if (question.kind == _QuestionKind.trueFalse) ...<Widget>[
          _CandidatePanel(text: question.candidate),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _TruthButton(
                  label: 'صحيح',
                  icon: CupertinoIcons.checkmark,
                  state: _stateFor(0),
                  delay: 90,
                  onTap: () => onPick(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TruthButton(
                  label: 'خطأ',
                  icon: CupertinoIcons.xmark,
                  state: _stateFor(1),
                  delay: 150,
                  onTap: () => onPick(1),
                ),
              ),
            ],
          ),
        ] else
          for (int index = 0; index < question.options.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionTile(
                letter: letters[index % letters.length],
                label: question.options[index],
                state: _stateFor(index),
                delay: 90 + index * 60,
                onTap: () => onPick(index),
              ),
            ),
      ],
    );
  }

  _OptionState _stateFor(int index) {
    final int? chosen = picked;
    if (chosen == null) {
      return _OptionState.idle;
    }
    if (index == question.correct) {
      return _OptionState.correct;
    }
    if (index == chosen) {
      return _OptionState.wrong;
    }
    return _OptionState.muted;
  }
}

enum _OptionState { idle, correct, wrong, muted }

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.letter,
    required this.label,
    required this.state,
    required this.delay,
    required this.onTap,
  });

  final String letter;
  final String label;
  final _OptionState state;
  final int delay;
  final VoidCallback onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(_OptionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == _OptionState.wrong &&
        oldWidget.state != _OptionState.wrong) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _OptionState state = widget.state;
    final bool correct = state == _OptionState.correct;
    final bool wrong = state == _OptionState.wrong;
    final bool muted = state == _OptionState.muted;

    final Color border = correct
        ? context.accent
        : wrong
        ? context.danger
        : context.hairline;
    final Color fill = correct
        ? context.softAccent
        : wrong
        ? context.danger.withValues(alpha: 0.09)
        : context.cardSurface;

    return AnimatedBuilder(
          animation: _shake,
          builder: (BuildContext context, Widget? child) {
            final double offset =
                math.sin(_shake.value * math.pi * 5) * (1 - _shake.value) * 9;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: muted ? 0.45 : 1,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: border,
                    width: correct || wrong ? 1.8 : 1,
                  ),
                  boxShadow: correct || wrong
                      ? <BoxShadow>[
                          BoxShadow(
                            color: (correct ? context.accent : context.danger)
                                .withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: context.isDark ? 0.3 : 0.04,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Row(
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: correct
                            ? context.accent
                            : wrong
                            ? context.danger
                            : context.raisedSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.letter,
                        style: TextStyle(
                          color: correct
                              ? context.onAccent
                              : wrong
                              ? context.onDanger
                              : context.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: correct
                              ? context.onSoftAccent
                              : wrong
                              ? context.danger
                              : context.ink,
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: correct || wrong
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (correct || wrong) ...<Widget>[
                      const SizedBox(width: 8),
                      Icon(
                        correct
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.xmark_circle_fill,
                        size: 20,
                        color: correct ? context.onSoftAccent : context.danger,
                      ).animate().scale(
                        begin: const Offset(0.4, 0.4),
                        end: const Offset(1, 1),
                        duration: 260.ms,
                        curve: Curves.easeOutBack,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 280.ms,
          delay: Duration(milliseconds: widget.delay),
        )
        .slideY(
          begin: 0.10,
          end: 0,
          duration: 340.ms,
          delay: Duration(milliseconds: widget.delay),
          curve: Curves.easeOutCubic,
        );
  }
}

/// The answer a true/false question asks the learner to judge.
class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(CupertinoIcons.quote_bubble, size: 12, color: context.muted),
              const SizedBox(width: 5),
              Text(
                'الإجابة المقترحة',
                style: TextStyle(
                  color: context.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: context.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two answers to a true/false question. Same verdict language as
/// the option tiles: green glow when right, a short shake when wrong.
class _TruthButton extends StatefulWidget {
  const _TruthButton({
    required this.label,
    required this.icon,
    required this.state,
    required this.delay,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _OptionState state;
  final int delay;
  final VoidCallback onTap;

  @override
  State<_TruthButton> createState() => _TruthButtonState();
}

class _TruthButtonState extends State<_TruthButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(_TruthButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == _OptionState.wrong &&
        oldWidget.state != _OptionState.wrong) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _OptionState state = widget.state;
    final bool correct = state == _OptionState.correct;
    final bool wrong = state == _OptionState.wrong;
    final bool muted = state == _OptionState.muted;

    final Color tint = correct
        ? context.accent
        : wrong
        ? context.danger
        : context.hairline;

    return AnimatedBuilder(
          animation: _shake,
          builder: (BuildContext context, Widget? child) {
            final double offset =
                math.sin(_shake.value * math.pi * 5) * (1 - _shake.value) * 8;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 240),
            opacity: muted ? 0.45 : 1,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                height: 86,
                decoration: BoxDecoration(
                  color: correct
                      ? context.softAccent
                      : wrong
                      ? context.danger.withValues(alpha: 0.09)
                      : context.cardSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tint,
                    width: correct || wrong ? 1.8 : 1,
                  ),
                  boxShadow: correct || wrong
                      ? <BoxShadow>[
                          BoxShadow(
                            color: tint.withValues(alpha: 0.35),
                            blurRadius: 22,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      widget.icon,
                      size: 22,
                      color: correct
                          ? context.onSoftAccent
                          : wrong
                          ? context.danger
                          : context.muted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'ReadexPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: correct
                            ? context.onSoftAccent
                            : wrong
                            ? context.danger
                            : context.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 260.ms,
          delay: Duration(milliseconds: widget.delay),
        )
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: 300.ms,
          delay: Duration(milliseconds: widget.delay),
          curve: Curves.easeOutBack,
        );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
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
    final bool great = score >= 0.8;
    final String headline = score >= 0.8
        ? 'أداء ممتاز!'
        : score >= 0.5
        ? 'جيد جدًا'
        : 'تحتاج مراجعة';
    final String note = score >= 0.8
        ? 'أنت تتقن هذه المجموعة، حافظ على الزخم.'
        : score >= 0.5
        ? 'أساس جيد، وراجع البطاقات التي أخطأت فيها.'
        : 'لا بأس، المراجعة أولًا ثم أعد الاختبار.';

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[context.primary, context.primaryDeep],
              ),
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -40,
          child: _Blob(color: context.accent, size: 220),
        ),
        Positioned(
          bottom: -80,
          right: -50,
          child: _Blob(color: context.info, size: 260),
        ),
        if (great)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiBurst(
                colors: <Color>[
                  context.accent,
                  context.primary,
                  context.info,
                  context.star,
                  context.accentDeep,
                ],
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _RoundIcon(
                    icon: CupertinoIcons.xmark,
                    label: 'إغلاق',
                    onTap: onClose,
                    onDark: true,
                  ),
                ),
                const Spacer(),
                _ScoreRing(score: score)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.86, 0.86),
                      end: const Offset(1, 1),
                      duration: 620.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 26),
                Text(
                  headline,
                  style: const TextStyle(
                    fontFamily: 'ReadexPro',
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 380.ms, delay: 180.ms),
                const SizedBox(height: 8),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ).animate().fadeIn(duration: 380.ms, delay: 260.ms),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    deckTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accent,
                      foregroundColor: context.onAccent,
                      minimumSize: const Size(52, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.refresh, size: 18),
                    label: const Text(
                      'أعد الاختبار',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: context.onPrimary.withValues(alpha: 0.75),
                  ),
                  child: const Text('إنهاء'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? _) {
        return SizedBox(
          width: 208,
          height: 208,
          child: CustomPaint(
            painter: _RingPainter(
              value: value,
              start: context.accent,
              end: Color.lerp(context.accent, context.primary, 0.55)!,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'ReadexPro',
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'إجابات صحيحة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.start,
    required this.end,
  });

  final double value;

  /// Gradient ends of the score arc. Passed in because a painter has no
  /// context to read the palette from.
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 12;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, track);

    if (value <= 0) {
      return;
    }
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: <Color>[start, end],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onDark = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: onDark
            ? Colors.white.withValues(alpha: 0.12)
            : context.raisedSurface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 17,
              color: onDark ? Colors.white : context.muted,
            ),
          ),
        ),
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
      backgroundColor: (context.canvas),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(CupertinoIcons.chevron_forward, color: context.ink),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: context.softAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.checkmark_seal,
                size: 34,
                color: context.onSoftAccent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'تحتاج بطاقتين على الأقل',
              style: TextStyle(
                fontFamily: 'ReadexPro',
                color: context.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deckTitle.isEmpty
                  ? 'أضف بطاقات إلى هذه المجموعة ثم أعد المحاولة.'
                  : 'أضف بطاقات إلى «$deckTitle» ثم أعد المحاولة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.muted,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
