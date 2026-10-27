import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/guest_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/card_markup.dart';
import '../../core/widgets/speak_button.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';

/// Loads the deck and the cards that are due now, then runs the session.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeckNode? found = ref.watch(deckByIdProvider(deckId));
    final bool listReady = ref.watch(deckListProvider).hasValue;
    final List<ReviewCard>? queue = ref
        .watch(studyQueueProvider(deckId))
        .valueOrNull;
    if ((found == null && !listReady) || queue == null) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    final DeckNode deck =
        found ?? DeckNode(id: deckId, title: '', color: AppColors.primary);
    return _ReviewSession(
      deck: deck,
      cards: found == null ? const <ReviewCard>[] : queue,
    );
  }
}

class _ReviewSession extends ConsumerStatefulWidget {
  const _ReviewSession({required this.deck, required this.cards});

  final DeckNode deck;
  final List<ReviewCard> cards;

  @override
  ConsumerState<_ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends ConsumerState<_ReviewSession> {
  late final DeckNode _deck = widget.deck;
  late List<ReviewCard> _cards;
  late int _remainingNew;
  late int _remainingLearning;
  late int _remainingReview;
  final List<ReviewCard> _hardCards = <ReviewCard>[];
  late final Set<String> _favorites;
  DateTime _shownAt = DateTime.now();
  DateTime _startedAt = DateTime.now();
  DateTime? _finishedAt;

  @override
  void initState() {
    super.initState();
    _cards = List<ReviewCard>.of(widget.cards);
    _favorites = <String>{
      for (final ReviewCard card in _cards)
        if (card.favorite) card.id,
    };
    _resetRemaining();
  }

  void _resetRemaining() {
    _remainingNew = _countPhase(_cards, CardPhase.newCard);
    _remainingLearning = _countPhase(_cards, CardPhase.learning);
    _remainingReview = _countPhase(_cards, CardPhase.review);
  }

  int _countPhase(List<ReviewCard> cards, CardPhase phase) =>
      cards.where((ReviewCard card) => card.phase == phase).length;

  int _index = 0;
  int _completed = 0;
  bool _revealed = false;
  bool _hintVisible = false;
  bool _finished = false;
  int _again = 0;
  int _hard = 0;
  int _good = 0;
  int _easy = 0;

  ReviewCard? get _current =>
      _cards.isEmpty || _index >= _cards.length ? null : _cards[_index];

  void _reveal() => setState(() => _revealed = true);

  void _rate(int rating) {
    switch (rating) {
      case 1:
        _again++;
      case 2:
        _hard++;
      case 3:
        _good++;
      case 4:
        _easy++;
    }
    final ReviewCard? answered = _current;
    if (answered != null) {
      if (rating <= 2 && !_hardCards.any((c) => c.id == answered.id)) {
        _hardCards.add(answered);
      }
      _decrementRemaining(answered.phase);
      unawaited(
        ref
            .read(contentRepositoryProvider)
            .recordReview(
              cardId: answered.id,
              rating: rating,
              elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds,
            ),
      );
    }
    final bool done = _index >= _cards.length - 1;
    setState(() {
      _completed++;
      _revealed = false;
      _hintVisible = false;
      if (done) {
        _finished = true;
        _finishedAt = DateTime.now();
      } else {
        _index++;
      }
    });
    _shownAt = DateTime.now();
  }

  void _decrementRemaining(CardPhase phase) {
    switch (phase) {
      case CardPhase.newCard:
        _remainingNew = (_remainingNew - 1).clamp(0, 999).toInt();
      case CardPhase.learning:
        _remainingLearning = (_remainingLearning - 1).clamp(0, 999).toInt();
      case CardPhase.review:
      case CardPhase.paused:
        _remainingReview = (_remainingReview - 1).clamp(0, 999).toInt();
    }
  }

  Future<void> _toggleFavorite(ReviewCard card) async {
    final bool next = !_favorites.contains(card.id);
    setState(() {
      if (next) {
        _favorites.add(card.id);
      } else {
        _favorites.remove(card.id);
      }
    });
    try {
      await ref
          .read(contentRepositoryProvider)
          .setCardFavorite(card.id, next);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (next) {
          _favorites.remove(card.id);
        } else {
          _favorites.add(card.id);
        }
      });
      showAppMessage(
        context,
        'تعذّر حفظ البطاقة المفضلة. حاول مرة أخرى.',
        kind: AppMessageKind.error,
      );
    }
  }

  Future<void> _editCard(ReviewCard card) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل البطاقات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    final String? message = await context.push<String>(
      '/edit-card/${card.id}?deckId=${card.deckId}',
    );
    if (message == null || !mounted) {
      return;
    }
    // The editor writes to the database, so re-read the card from the stream
    // instead of trusting a stale copy.
    ReviewCard? updated;
    for (final ReviewCard candidate
        in ref.read(deckCardsProvider(card.deckId)).valueOrNull ??
            const <ReviewCard>[]) {
      if (candidate.id == card.id) {
        updated = candidate;
      }
    }
    setState(() {
      if (updated != null) {
        _cards[_index] = updated;
      }
      _revealed = false;
      _hintVisible = false;
    });
    _shownAt = DateTime.now();
    showAppMessage(context, message);
  }

  Future<void> _snooze(ReviewCard card) async {
    try {
      await ref.read(contentRepositoryProvider).snoozeCard(cardId: card.id);
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'تعذّر تأجيل البطاقة. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    showAppMessage(
      context,
      'ستعود البطاقة إلى المراجعة بعد 10 دقائق.',
      kind: AppMessageKind.info,
    );
    _decrementRemaining(card.phase);
    final bool done = _index >= _cards.length - 1;
    setState(() {
      _revealed = false;
      _hintVisible = false;
      if (done) {
        _finished = true;
        _finishedAt = DateTime.now();
      } else {
        _index++;
      }
    });
    _shownAt = DateTime.now();
  }

  void _restart() {
    _shownAt = DateTime.now();
    _startedAt = DateTime.now();
    _finishedAt = null;
    setState(() {
      _cards = _hardCards.isNotEmpty
          ? List<ReviewCard>.of(_hardCards)
          : List<ReviewCard>.of(widget.cards);
      _hardCards.clear();
      _resetRemaining();
      _index = 0;
      _completed = 0;
      _revealed = false;
      _hintVisible = false;
      _finished = false;
      _again = 0;
      _hard = 0;
      _good = 0;
      _easy = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    CupertinoIcons.tray,
                    size: 44,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'لا توجد بطاقات للمراجعة',
                    style: TextStyle(
                      fontFamily: 'ReadexPro',
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد بطاقات مستحقة الآن. عد لاحقاً أو أضف بطاقات جديدة.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_finished) {
      return _Summary(
        deck: _deck,
        total: _cards.length,
        completed: _completed,
        again: _again,
        hard: _hard,
        good: _good,
        easy: _easy,
        duration: (_finishedAt ?? DateTime.now()).difference(_startedAt),
        hardCount: _hardCards.length,
        onRestart: _restart,
        onClose: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      );
    }

    final double progress = _cards.isEmpty ? 0 : _completed / _cards.length;
    final ReviewCard card = _current!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _DarkRoundButton(
                    icon: CupertinoIcons.xmark,
                    label: 'إغلاق',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.primaryDeep,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_completed + 1} / ${_cards.length}',
                    style: const TextStyle(
                      fontFamily: 'ReadexPro',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _Legend(
                    text: 'جديدة $_remainingNew',
                    active: card.phase == CardPhase.newCard,
                  ),
                  const SizedBox(width: 14),
                  _Legend(
                    text: 'تعلّم $_remainingLearning',
                    active: card.phase == CardPhase.learning,
                  ),
                  const SizedBox(width: 14),
                  _Legend(
                    text: 'مراجعة $_remainingReview',
                    active:
                        card.phase == CardPhase.review ||
                        card.phase == CardPhase.paused,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: 14,
                      left: 12,
                      right: 12,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFCFE0C4),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      left: 6,
                      right: 6,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCECD0),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: _revealed
                              ? AppColors.answerSurface
                              : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: _revealed
                              ? Border.all(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1.2,
                                )
                              : null,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _revealed ? 0.42 : 0.18,
                              ),
                              blurRadius: _revealed ? 34 : 26,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: _CardBody(
                          card: card,
                          deck: _deck,
                          revealed: _revealed,
                          position: _index + 1,
                          hintVisible: _hintVisible,
                          favorite: _favorites.contains(card.id),
                          onToggleFavorite: () => _toggleFavorite(card),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (card.hint != null) ...<Widget>[
                    _SoftAction(
                      icon: CupertinoIcons.lightbulb,
                      label: _hintVisible ? 'إخفاء التلميح' : 'تلميح',
                      onTap: () =>
                          setState(() => _hintVisible = !_hintVisible),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _SoftAction(
                    icon: CupertinoIcons.pencil,
                    label: 'تعديل',
                    onTap: () => _editCard(card),
                  ),
                  const SizedBox(width: 8),
                  _SoftAction(
                    icon: CupertinoIcons.clock,
                    label: 'تأجيل',
                    onTap: () => _snooze(card),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!_revealed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _reveal,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(52, 54),
                    ),
                    child: const Text('أظهر الإجابة'),
                  ),
                )
              else
                _RatingBar(onRate: _rate),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.card,
    required this.deck,
    required this.revealed,
    required this.position,
    required this.hintVisible,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final ReviewCard card;
  final DeckNode deck;
  final bool revealed;
  final int position;
  final bool hintVisible;
  final bool favorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final Color ink = revealed ? Colors.white : context.ink;
    final Color muted = revealed
        ? Colors.white.withValues(alpha: 0.62)
        : context.muted;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: revealed
                      ? AppColors.primaryDeep
                      : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  deck.title,
                  style: TextStyle(
                    color: revealed ? AppColors.accent : AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'بطاقة $position',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onToggleFavorite,
                tooltip: favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: Icon(
                  favorite ? CupertinoIcons.star_fill : CupertinoIcons.star,
                  size: 20,
                  color: favorite ? AppColors.accent : muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!revealed) ...<Widget>[
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(
                    deck.icon,
                    size: 74,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 14,
                    child: Text(
                      deck.title,
                      style: const TextStyle(
                        color: AppColors.primaryDeep,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Text(
                  'السؤال',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                SpeakButton(
                  text: card.front,
                  size: 34,
                  tint: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (card.type == 'occlusion')
              OcclusionView(
                imageUrl: occlusionImageUrl(card.front),
                boxes: occlusionBoxes(card.occlusion),
                masked: true,
                height: 210,
              )
            else
              CardMarkup(
                text: card.front,
                revealCloze: false,
                mediaFirst: true,
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 24,
                  height: 1.55,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
                mediaHeight: 190,
              ),
            if (card.hint != null && hintVisible) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      CupertinoIcons.lightbulb,
                      size: 16,
                      color: AppColors.warningInk,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.hint!,
                        style: const TextStyle(
                          color: AppColors.warningInk,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...<Widget>[
            CardMarkup(
              text: card.front,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.6,
              ),
              mediaHeight: 140,
            ),
            const SizedBox(height: 12),
            Container(height: 0.7, color: AppColors.primaryDeep),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text(
                        'الإجابة',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Spacer(),
                      SpeakButton(
                        text: card.back,
                        size: 34,
                        tint: AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (card.type == 'occlusion') ...<Widget>[
                    OcclusionView(
                      imageUrl: occlusionImageUrl(card.front),
                      boxes: occlusionBoxes(card.occlusion),
                      masked: false,
                      height: 210,
                    ),
                    const SizedBox(height: 12),
                  ],
                  CardMarkup(
                    text: card.back,
                    style: const TextStyle(
                      fontFamily: 'ReadexPro',
                      color: AppColors.accent,
                      fontSize: 26,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                    mediaHeight: 190,
                  ),
                ],
              ),
            ),
            if (card.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  for (final String tag in card.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (card.note != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ملاحظتي',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      card.note!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.onRate});

  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    const List<_RatingSpec> specs = <_RatingSpec>[
      _RatingSpec(label: 'نسيتها', interval: 'دقيقة', color: AppColors.danger),
      _RatingSpec(label: 'صعبة', interval: 'يومان', color: Colors.white),
      _RatingSpec(label: 'جيدة', interval: '5 أيام', color: AppColors.accent),
      _RatingSpec(
        label: 'سهلة',
        interval: '11 يوماً',
        color: Color(0xFF054D28),
      ),
    ];

    return Row(
      children: <Widget>[
        for (int index = 0; index < specs.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: _RatingButton(
              spec: specs[index],
              onTap: () => onRate(index + 1),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({required this.spec, required this.onTap});

  final _RatingSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool light = spec.color == Colors.white;
    final bool dark = spec.color == const Color(0xFF054D28);
    final bool danger = spec.color == AppColors.danger;
    final Color background = light ? Colors.white : spec.color;
    final Color foreground = light
        ? AppColors.primary
        : dark
        ? AppColors.accent
        : danger
        ? Colors.white
        : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: light
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.6))
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              spec.label,
              style: TextStyle(
                fontFamily: 'ReadexPro',
                color: foreground,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              spec.interval,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.66),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({
    required this.deck,
    required this.total,
    required this.completed,
    required this.again,
    required this.hard,
    required this.good,
    required this.easy,
    required this.duration,
    required this.hardCount,
    required this.onRestart,
    required this.onClose,
  });

  final DeckNode deck;
  final int total;
  final int completed;
  final int again;
  final int hard;
  final int good;
  final int easy;
  final Duration duration;
  final int hardCount;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final List<DueForecastDay> forecast =
        ref.watch(dueForecastProvider).valueOrNull ?? const <DueForecastDay>[];
    final int tomorrow = forecast.length > 1 ? forecast[1].count : 0;
    final int correct = hard + good + easy;
    final int answered = again + hard + good + easy;
    final int accuracy = answered == 0
        ? 0
        : (correct / answered * 100).round();
    final String streakLabel = streak == 2
        ? 'يومان'
        : '$streak ${_dayWord(streak)}';
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          children: <Widget>[
            Center(
              child: Container(
                width: 94,
                height: 94,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark,
                  color: AppColors.primary,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'أنهيت مراجعة اليوم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ReadexPro',
                color: context.ink,
                fontSize: 29,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completed من $total بطاقة في ${_formatDuration(duration)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.muted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryStat(
                    value: '$accuracy%',
                    label: 'دقة الإجابات',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryStat(
                    value: '$correct',
                    label: 'إجابات صحيحة',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryStat(
                    value: _durationShort(duration),
                    label: 'وقت الجلسة',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: again == 0 ? 1 : again,
                      child: const ColoredBox(color: AppColors.danger),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: hard == 0 ? 1 : hard,
                      child: const ColoredBox(color: AppColors.muted),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: good == 0 ? 1 : good,
                      child: const ColoredBox(color: AppColors.accent),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: easy == 0 ? 1 : easy,
                      child: const ColoredBox(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('نسيتها $again', style: const TextStyle(fontSize: 11)),
                Text('صعبة $hard', style: const TextStyle(fontSize: 11)),
                Text('جيدة $good', style: const TextStyle(fontSize: 11)),
                Text('سهلة $easy', style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    CupertinoIcons.flame,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'سلسلتك $streakLabel',
                          style: const TextStyle(
                            fontFamily: 'ReadexPro',
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          tomorrow == 0
                              ? 'لا بطاقات مستحقة غداً'
                              : 'غداً: $tomorrow ${tomorrow == 1 ? 'بطاقة' : 'بطاقات'} بانتظارك',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('العودة إلى المجموعات'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRestart,
              child: Text(
                hardCount > 0
                    ? 'راجع البطاقات الصعبة الآن ($hardCount)'
                    : 'إعادة الجلسة',
                style: TextStyle(
                  color: context.brandInk,
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deck.title,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: context.muted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.text, this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: active
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.accent, width: 2),
              ),
            )
          : null,
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: context.raisedSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 14, color: context.brandInk),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.brandInk,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkRoundButton extends StatelessWidget {
  const _DarkRoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryDeep,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _RatingSpec {
  const _RatingSpec({
    required this.label,
    required this.interval,
    required this.color,
  });

  final String label;
  final String interval;
  final Color color;
}

String _formatDuration(Duration duration) {
  if (duration.inMinutes < 1) {
    final int seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
    return '$seconds ثانية';
  }
  if (duration.inHours < 1) {
    return '${duration.inMinutes} دقيقة';
  }
  final int minutes = duration.inMinutes.remainder(60);
  return '${duration.inHours} س $minutes د';
}

String _durationShort(Duration duration) {
  if (duration.inMinutes < 1) {
    return '${duration.inSeconds < 1 ? 1 : duration.inSeconds}ث';
  }
  if (duration.inHours < 1) {
    return '${duration.inMinutes}د';
  }
  return '${duration.inHours}س ${duration.inMinutes.remainder(60)}د';
}

String _dayWord(int days) {
  if (days == 1) {
    return 'يوم';
  }
  if (days == 2) {
    return 'يومان';
  }
  if (days >= 3 && days <= 10) {
    return 'أيام';
  }
  return 'يوماً';
}
