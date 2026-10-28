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
import '../../domain/models.dart';

/// A match-the-pair game that behaves like a falling-block board instead of a
/// static grid.
///
/// The board holds three pairs at a time. When a pair is cleared the remaining
/// tiles keep their identity and slide into the freed slots, and a fresh pair
/// drops in from above with a bounce. The deck is consumed pair by pair, so the
/// game keeps flowing until nothing is left.
class MatchGameScreen extends ConsumerWidget {
  const MatchGameScreen({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeckNode? deck = ref.watch(deckByIdProvider(deckId));
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
    // Only plain two-sided cards can become a pair of tiles. An occlusion card
    // is a picture and a cloze card hides its answer inside its own question,
    // so neither has a front and a back to match — counting them as "cards in
    // the deck" is what used to produce a game that refused to start on a
    // deck the library showed as having cards.
    final List<ReviewCard> usable = <ReviewCard>[
      for (final ReviewCard card in cards)
        if (card.type == 'basic' &&
            plainMarkup(card.front).trim().isNotEmpty &&
            plainMarkup(card.back).trim().isNotEmpty)
          card,
    ];
    if (usable.length < 2) {
      return _NotEnough(
        deckTitle: deck?.title ?? 'جميع المجموعات',
        deckHasCards: cards.isNotEmpty,
      );
    }
    return _MatchGame(
      deckTitle: deck?.title ?? 'جميع المجموعات',
      cards: usable,
    );
  }
}

class _MatchTile {
  const _MatchTile({
    required this.id,
    required this.pairId,
    required this.label,
    required this.isQuestion,
  });

  final String id;
  final String pairId;
  final String label;
  final bool isQuestion;
}

class _MatchGame extends ConsumerStatefulWidget {
  const _MatchGame({required this.deckTitle, required this.cards});

  final String deckTitle;
  final List<ReviewCard> cards;

  @override
  ConsumerState<_MatchGame> createState() => _MatchGameState();
}

class _MatchGameState extends ConsumerState<_MatchGame> {
  static const int _rows = 3;

  final math.Random _random = math.Random();
  final Stopwatch _watch = Stopwatch();
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );
  final List<Timer> _timers = <Timer>[];
  Timer? _ticker;

  late List<List<_MatchTile>> _columns;
  late List<ReviewCard> _queue;
  final List<_MatchTile> _pending = <_MatchTile>[];
  final Set<String> _matched = <String>{};
  final Set<String> _wrong = <String>{};
  String? _selected;
  int _cleared = 0;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _ticker?.cancel();
    _elapsed.dispose();
    _watch.stop();
    super.dispose();
  }

  void _reset() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _ticker?.cancel();
    _queue = List<ReviewCard>.of(widget.cards)..shuffle(_random);
    _columns = <List<_MatchTile>>[<_MatchTile>[], <_MatchTile>[]];
    _pending.clear();
    _matched.clear();
    _wrong.clear();
    _selected = null;
    _cleared = 0;
    _won = false;
    _topUp();
    for (final List<_MatchTile> column in _columns) {
      while (column.length < _rows && _pending.isNotEmpty) {
        column.add(_pending.removeAt(0));
      }
    }
    _elapsed.value = Duration.zero;
    _watch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (Timer _) {
      if (mounted) {
        _elapsed.value = _watch.elapsed;
      }
    });
  }

  /// Pulls whole pairs into the buffer so a tile can never be left without its
  /// partner, then shuffles what is waiting.
  void _topUp() {
    while (_pending.length < _rows * 2 && _queue.isNotEmpty) {
      final ReviewCard card = _queue.removeAt(0);
      _pending
        ..add(
          _MatchTile(
            id: '${card.id}-q',
            pairId: card.id,
            label: plainMarkup(card.front).trim(),
            isQuestion: true,
          ),
        )
        ..add(
          _MatchTile(
            id: '${card.id}-a',
            pairId: card.id,
            label: plainMarkup(card.back).trim(),
            isQuestion: false,
          ),
        );
    }
    _pending.shuffle(_random);
  }

  _MatchTile? _find(String id) {
    for (final List<_MatchTile> column in _columns) {
      for (final _MatchTile tile in column) {
        if (tile.id == id) {
          return tile;
        }
      }
    }
    return null;
  }

  void _tap(_MatchTile tile) {
    if (_matched.isNotEmpty) {
      return;
    }
    final String? selected = _selected;
    if (selected == tile.id) {
      setState(() => _selected = null);
      return;
    }
    if (selected == null) {
      HapticFeedback.selectionClick();
      setState(() => _selected = tile.id);
      return;
    }
    final _MatchTile? first = _find(selected);
    if (first == null) {
      setState(() => _selected = tile.id);
      return;
    }
    if (first.pairId == tile.pairId && first.isQuestion != tile.isQuestion) {
      _clear(first, tile);
    } else {
      _reject(first, tile);
    }
  }

  /// A match is a successful recall and a mismatch is a failed one, so the
  /// game feeds the same scheduler as the review screen. The first tile is the
  /// one the learner committed to, which is why it is the one that gets marked
  /// on a mismatch.
  void _record(String cardId, {required bool good}) {
    unawaited(
      ref
          .read(contentRepositoryProvider)
          .recordReview(cardId: cardId, rating: good ? 3 : 1, allowEarly: true)
          .catchError((Object error) {
            if (!mounted) {
              return;
            }
            showAppMessage(
              context,
              'تعذّر حفظ نتيجة المطابقة في جدول المراجعة.',
              kind: AppMessageKind.error,
            );
          }),
    );
  }

  void _clear(_MatchTile a, _MatchTile b) {
    unawaited(SoundService.instance.correct());
    HapticFeedback.heavyImpact();
    _record(a.pairId, good: true);
    setState(() {
      _selected = null;
      _matched
        ..clear()
        ..addAll(<String>[a.id, b.id]);
      _cleared++;
    });
    _timers.add(
      Timer(const Duration(milliseconds: 470), () {
        if (!mounted) {
          return;
        }
        setState(() {
          for (final List<_MatchTile> column in _columns) {
            column.removeWhere((_MatchTile tile) => _matched.contains(tile.id));
          }
          _matched.clear();
          _refill();
          if (_columns.every((List<_MatchTile> c) => c.isEmpty) &&
              _pending.isEmpty &&
              _queue.isEmpty) {
            _won = true;
            _watch.stop();
            _ticker?.cancel();
            _elapsed.value = _watch.elapsed;
          }
        });
        if (_won) {
          HapticFeedback.heavyImpact();
        }
      }),
    );
  }

  void _reject(_MatchTile a, _MatchTile b) {
    HapticFeedback.heavyImpact();
    _record(a.pairId, good: false);
    setState(() {
      _selected = null;
      _wrong
        ..clear()
        ..addAll(<String>[a.id, b.id]);
    });
    _timers.add(
      Timer(const Duration(milliseconds: 460), () {
        if (mounted) {
          setState(() => _wrong.clear());
        }
      }),
    );
  }

  void _refill() {
    _topUp();
    bool placed = true;
    while (placed && _pending.isNotEmpty) {
      placed = false;
      for (final List<_MatchTile> column in _columns) {
        if (column.length < _rows && _pending.isNotEmpty) {
          column.insert(0, _pending.removeAt(0));
          placed = true;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _Header(
                  deckTitle: widget.deckTitle,
                  elapsed: _elapsed,
                  cleared: _cleared,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: _Board(
                      columns: _columns,
                      rows: _rows,
                      selected: _selected,
                      matched: _matched,
                      wrong: _wrong,
                      onTap: _tap,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        CupertinoIcons.hand_draw,
                        size: 13,
                        color: context.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'اضغط السؤال ثم إجابته المطابقة',
                        style: TextStyle(
                          color: context.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_won)
              Positioned.fill(
                child: _Victory(
                  elapsed: _watch.elapsed,
                  cleared: _cleared,
                  onReplay: _reset,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.deckTitle,
    required this.elapsed,
    required this.cleared,
    required this.onClose,
  });

  final String deckTitle;
  final ValueNotifier<Duration> elapsed;
  final int cleared;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: <Widget>[
          Material(
            color: context.raisedSurface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onClose,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 17,
                  color: context.muted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'المطابقة',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    color: context.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deckTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _Stopwatch(elapsed: elapsed),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.softAccent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 12,
                  color: context.onSoftAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '$cleared',
                  style: TextStyle(
                    color: context.onSoftAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stopwatch extends StatelessWidget {
  const _Stopwatch({required this.elapsed});

  final ValueNotifier<Duration> elapsed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: elapsed,
      builder: (BuildContext context, Duration value, Widget? _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[context.cardSurface, context.raisedSurface],
            ),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: context.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(CupertinoIcons.time, size: 12, color: context.muted),
              const SizedBox(width: 5),
              Text(
                _clock(value),
                style: TextStyle(
                  color: context.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _clock(Duration value) {
  final int total = value.inSeconds;
  final int minutes = total ~/ 60;
  final int seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _Board extends StatelessWidget {
  const _Board({
    required this.columns,
    required this.rows,
    required this.selected,
    required this.matched,
    required this.wrong,
    required this.onTap,
  });

  final List<List<_MatchTile>> columns;
  final int rows;
  final String? selected;
  final Set<String> matched;
  final Set<String> wrong;
  final ValueChanged<_MatchTile> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // A board, not a table. The tiles used to divide the whole screen, so
        // two columns on a phone produced 180x270 cards glued to each other.
        // They now cap at a size a thumb can hit and a game board reads as,
        // and the whole grid is centred in whatever space is left.
        const double gap = 10;
        const double maxTileWidth = 144;
        const double maxTileHeight = 108;

        final int columnCount = columns.length;
        final double columnWidth = math.min(
          (constraints.maxWidth - gap * (columnCount - 1)) / columnCount,
          maxTileWidth,
        );
        final double tileHeight = math.min(
          math.min(
            (constraints.maxHeight - gap * (rows - 1)) / rows,
            maxTileHeight,
          ),
          columnWidth * 0.86,
        );
        final double boardWidth =
            columnWidth * columnCount + gap * (columnCount - 1);
        final double boardHeight = tileHeight * rows + gap * (rows - 1);
        final double originX = math.max(
          0,
          (constraints.maxWidth - boardWidth) / 2,
        );
        final double originY = math.max(
          0,
          (constraints.maxHeight - boardHeight) / 2,
        );

        final List<Widget> tiles = <Widget>[];
        for (int column = 0; column < columns.length; column++) {
          final List<_MatchTile> stack = columns[column];
          final double left =
              originX + (columns.length - 1 - column) * (columnWidth + gap);
          for (int index = 0; index < stack.length; index++) {
            final _MatchTile tile = stack[index];
            final int row = rows - stack.length + index;
            tiles.add(
              AnimatedPositioned(
                key: ValueKey<String>(tile.id),
                duration: const Duration(milliseconds: 430),
                curve: Curves.easeOutCubic,
                left: left,
                top: originY + row * (tileHeight + gap),
                width: columnWidth,
                height: tileHeight,
                child: _TileView(
                  tile: tile,
                  selected: selected == tile.id,
                  removing: matched.contains(tile.id),
                  wrong: wrong.contains(tile.id),
                  onTap: () => onTap(tile),
                ),
              ),
            );
          }
        }
        return Stack(clipBehavior: Clip.none, children: tiles);
      },
    );
  }
}

class _TileView extends StatefulWidget {
  const _TileView({
    required this.tile,
    required this.selected,
    required this.removing,
    required this.wrong,
    required this.onTap,
  });

  final _MatchTile tile;
  final bool selected;
  final bool removing;
  final bool wrong;
  final VoidCallback onTap;

  @override
  State<_TileView> createState() => _TileViewState();
}

class _TileViewState extends State<_TileView> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..forward();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  late final double _phase = (widget.tile.id.hashCode % 1000) / 1000;
  bool _pressed = false;

  @override
  void didUpdateWidget(_TileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) {
      _exit.forward();
    }
    if (widget.wrong && !oldWidget.wrong) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    _exit.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool question = widget.tile.isQuestion;
    final bool on = widget.selected;

    final Color base = question ? context.primary : context.cardSurface;
    final Color deep = question ? context.primaryDeep : context.softAccent;
    final Color ink = question ? context.onPrimary : context.ink;
    final Color sub = question
        ? context.accent.withValues(alpha: 0.9)
        : context.muted;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_enter, _float, _exit, _shake]),
      builder: (BuildContext context, Widget? child) {
        final double enter = Curves.bounceOut.transform(_enter.value);
        final double exit = _exit.value;
        final double drift =
            math.sin((_float.value + _phase) * math.pi * 2) * 2.6;
        final double tilt =
            math.sin((_float.value + _phase) * math.pi * 2) * 0.008;
        final double jitter =
            math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 7;

        return Transform.translate(
          offset: Offset(jitter, -(1 - enter) * 430 - exit * 90 + drift),
          child: Transform.rotate(
            angle: tilt + exit * 0.10,
            child: Transform.scale(
              scale: (on ? 1.045 : 1) + exit * 0.18,
              child: Opacity(opacity: (1 - exit).clamp(0.0, 1.0), child: child),
            ),
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.955 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: on
                    ? <Color>[
                        Color.lerp(base, Colors.white, 0.12)!,
                        Color.lerp(deep, Colors.white, 0.06)!,
                      ]
                    : <Color>[base, deep],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: on
                    ? context.accent
                    : widget.wrong
                    ? context.danger
                    : question
                    ? context.primaryDeep
                    : context.hairline,
                width: on ? 2 : 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: on
                      ? context.accent.withValues(alpha: 0.5)
                      : Colors.black.withValues(
                          alpha: context.isDark ? 0.4 : 0.07,
                        ),
                  blurRadius: on ? 22 : 12,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      question
                          ? CupertinoIcons.question_circle
                          : CupertinoIcons.arrow_turn_down_right,
                      size: 11,
                      color: sub,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      question ? 'سؤال' : 'إجابة',
                      style: TextStyle(
                        color: sub,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Text(
                      widget.tile.label,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: question
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
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

class _Victory extends StatelessWidget {
  const _Victory({
    required this.elapsed,
    required this.cleared,
    required this.onReplay,
    required this.onClose,
  });

  final Duration elapsed;
  final int cleared;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final String seconds = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.62),
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
        ),
        Center(
          child:
              Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                      decoration: BoxDecoration(
                        color: context.cardSurface,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 40,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: <Color>[
                                  context.accent,
                                  context.accentDeep,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: context.accent.withValues(alpha: 0.5),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              CupertinoIcons.rosette,
                              size: 34,
                              color: context.primary,
                            ),
                          ).animate().scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1, 1),
                            duration: 520.ms,
                            curve: Curves.easeOutBack,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'أكملت المجموعة!',
                            style: TextStyle(
                              fontFamily: 'ReadexPro',
                              color: context.ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'طابقت كل الأزواج في هذه الجلسة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.muted,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _VictoryStat(
                                  label: 'الوقت',
                                  value: '$seconds ث',
                                  icon: CupertinoIcons.time,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _VictoryStat(
                                  label: 'الأزواج',
                                  value: '$cleared',
                                  icon: CupertinoIcons.checkmark_alt,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onReplay,
                              style: FilledButton.styleFrom(
                                backgroundColor: context.primary,
                                foregroundColor: context.accent,
                                minimumSize: const Size(52, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'أعد اللعب',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: onClose,
                            style: TextButton.styleFrom(
                              foregroundColor: context.muted,
                            ),
                            child: const Text('إنهاء'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 420.ms,
                    curve: Curves.easeOutCubic,
                  ),
        ),
      ],
    );
  }
}

class _VictoryStat extends StatelessWidget {
  const _VictoryStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 14, color: context.muted),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: context.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEnough extends StatelessWidget {
  const _NotEnough({required this.deckTitle, required this.deckHasCards});

  final String deckTitle;

  /// True when the deck has cards, just none this game can use. The two cases
  /// need different words: one is "write something", the other is "these
  /// cards are not tiles".
  final bool deckHasCards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvas,
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
                CupertinoIcons.square_grid_2x2,
                size: 32,
                color: context.onSoftAccent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'تحتاج بطاقتين نصيتين على الأقل',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ReadexPro',
                color: context.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deckHasCards
                  ? 'بطاقات تغطية الصور وملء الفراغات لا تظهر في هذه اللعبة. '
                        'أضف بطاقتين نصيتين إلى «$deckTitle» ثم أعد المحاولة.'
                  : deckTitle.isEmpty
                  ? 'أضف بطاقتين نصيتين إلى هذه المجموعة ثم أعد المحاولة.'
                  : 'أضف بطاقتين نصيتين إلى «$deckTitle» ثم أعد المحاولة.',
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
