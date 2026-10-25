import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({required this.deckId, super.key});

  final String deckId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final DeckSummary _deck = findDeck(widget.deckId);
  late final List<ReviewCard> _cards = cardsForDeck(_deck);

  int _index = 0;
  int _completed = 0;
  bool _revealed = false;
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
    final bool done = _index >= _cards.length - 1;
    setState(() {
      _completed++;
      _revealed = false;
      if (done) {
        _finished = true;
      } else {
        _index++;
      }
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _completed = 0;
      _revealed = false;
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
                    'أضف بطاقات إلى هذه المجموعة أولاً.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.pop(),
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
        again: _again,
        hard: _hard,
        good: _good,
        easy: _easy,
        onRestart: _restart,
        onClose: () => context.pop(),
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
                    onTap: () => context.pop(),
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
                  _Legend(text: 'جديدة 8', active: true),
                  const SizedBox(width: 14),
                  _Legend(text: 'تعلّم 2'),
                  const SizedBox(width: 14),
                  _Legend(text: 'مراجعة 14'),
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
                          color: _revealed ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: _CardBody(
                          card: card,
                          deck: _deck,
                          revealed: _revealed,
                          position: _index + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
  });

  final ReviewCard card;
  final DeckSummary deck;
  final bool revealed;
  final int position;

  @override
  Widget build(BuildContext context) {
    final Color ink = revealed ? Colors.white : AppColors.ink;
    final Color muted = revealed
        ? Colors.white.withValues(alpha: 0.62)
        : AppColors.muted;

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
                  '${deck.subject.nameAr} · ${deck.title.split('·').last.trim()}',
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
              const SizedBox(width: 8),
              Icon(CupertinoIcons.star, size: 20, color: muted),
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
                    deck.subject.icon,
                    size: 74,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 14,
                    child: Text(
                      'الشكل التوضيحي · ${deck.subject.nameAr}',
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
            Text(
              'السؤال',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              card.front,
              style: TextStyle(
                fontFamily: 'ReadexPro',
                fontSize: 24,
                height: 1.55,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            if (card.hint != null) ...<Widget>[
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
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                _SoftAction(
                  icon: CupertinoIcons.lightbulb,
                  label: 'تلميح',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _SoftAction(
                  icon: CupertinoIcons.pencil,
                  label: 'تعديل',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _SoftAction(
                  icon: CupertinoIcons.clock,
                  label: 'تأجيل',
                  onTap: () {},
                ),
              ],
            ),
          ] else ...<Widget>[
            Text(
              card.front,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 0.7, color: AppColors.primaryDeep),
            const SizedBox(height: 12),
            const Text(
              'الإجابة',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              card.back,
              style: const TextStyle(
                fontFamily: 'ReadexPro',
                color: AppColors.accent,
                fontSize: 26,
                height: 1.5,
                fontWeight: FontWeight.w700,
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
    final Color background = light ? Colors.white : spec.color;
    final Color foreground = light
        ? AppColors.primary
        : dark
        ? AppColors.accent
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.deck,
    required this.total,
    required this.again,
    required this.hard,
    required this.good,
    required this.easy,
    required this.onRestart,
    required this.onClose,
  });

  final DeckSummary deck;
  final int total;
  final int again;
  final int hard;
  final int good;
  final int easy;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
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
            const Text(
              'أنهيت مراجعة اليوم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ReadexPro',
                color: AppColors.ink,
                fontSize: 29,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$total بطاقة في 7 دقائق',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryStat(
                    value: '${((good + easy) / total * 100).round()}%',
                    label: 'إجابات صحيحة',
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _SummaryStat(value: '+3', label: 'راسخة جديدة'),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _SummaryStat(value: '7', label: 'دقائق'),
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
                        const Text(
                          'سلسلتك 13 يوماً',
                          style: TextStyle(
                            fontFamily: 'ReadexPro',
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'غداً: 18 بطاقة بانتظارك',
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
                'راجع البطاقات الصعبة الآن (${again + hard})',
                style: const TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deck.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
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
