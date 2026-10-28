import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_header.dart';
import '../../data/content_providers.dart';
import '../../domain/gamification.dart';
import '../../domain/models.dart';
import '../create/create_sheet.dart';
import '../study/study_mode_sheet.dart';

const List<String> _months = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Sunday first, matching the Arabic week.
const List<String> _weekdays = <String>[
  'أحد',
  'اثن',
  'ثلا',
  'أرب',
  'خمي',
  'جمع',
  'سبت',
];

/// The gamified dashboard.
///
/// Every number on this screen is derived from the local database through
/// [progressSummaryProvider]: review history, the deck table and the due
/// forecast. Nothing is cached, seeded or invented, so the dashboard can never
/// show a streak the calendar disagrees with.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProgressSummary summary = ref.watch(progressSummaryProvider);
    final List<DueForecastDay> forecast =
        ref.watch(dueForecastProvider).valueOrNull ?? const <DueForecastDay>[];
    final DeckNode? todayDeck = ref.watch(todayReviewDeckProvider);
    final DeckNode? startDeck = todayDeck ?? _firstDeckWithCards(ref);
    final int dueTotal = ref.watch(totalDueProvider);
    // With no review history every chart below is a row of zeros, which reads
    // as "you are doing badly" rather than "you have not started". The
    // panels are replaced by one explanation until there is something real to
    // draw.
    final bool hasActivity = summary.totalReviews > 0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 118),
        children: <Widget>[
          _Header(summary: summary),
          _LevelCard(summary: summary),
          if (startDeck != null)
            _StartCard(
              deck: startDeck,
              dueCount: dueTotal,
              firstRun: !hasActivity,
            ),
          if (!hasActivity) _FirstRunPanel(hasDeck: startDeck != null),
          if (hasActivity) _StreakCard(summary: summary),
          _AchievementsSection(summary: summary),
          if (hasActivity) _RetentionCard(summary: summary),
          if (hasActivity) _ForecastCard(forecast: forecast),
          if (hasActivity) _HeatmapCard(summary: summary),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  DeckNode? _firstDeckWithCards(WidgetRef ref) {
    for (final DeckNode deck in ref.watch(allDecksProvider)) {
      if (deck.cardCount > 0) {
        return deck;
      }
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('تقدّمي', style: context.texts.headlineLarge),
                const SizedBox(height: 2),
                Text(
                  'كل مراجعة تقرّبك من الإتقان',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: context.softAccent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.flame_fill,
                  size: 13,
                  color: context.onSoftAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${summary.currentStreak}',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.onSoftAccent,
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    // One tween drives the ring, the bar and the XP counter, so the whole card
    // fills up in one motion instead of three that disagree.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, Widget? child) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.primary, Color(0xFF2D5410)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 94,
                      height: 94,
                      child: CustomPaint(
                        painter: _LevelRingPainter(
                          progress: summary.levelProgress * t,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'المستوى',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${summary.level}',
                                style: const TextStyle(
                                  fontFamily: 'ReadexPro',
                                  color: Colors.white,
                                  fontSize: 30,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            summary.levelTitle,
                            style: const TextStyle(
                              fontFamily: 'ReadexPro',
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_thousands((summary.xp * t).round())} XP',
                            style: const TextStyle(
                              fontFamily: 'ReadexPro',
                              color: Colors.white,
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${summary.totalReviews} مراجعة · '
                            '${summary.deckCount} مجموعة',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.66),
                              fontSize: 10.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Text(
                      'المستوى ${summary.level + 1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${summary.xpIntoLevel} / ${summary.levelSpan} XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    return Stack(
                      children: <Widget>[
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: box.maxWidth * summary.levelProgress * t,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelRingPainter extends CustomPainter {
  const _LevelRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2 - 5;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    if (progress <= 0) {
      return;
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_LevelRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// The one action the dashboard wants from the learner right now: finish
/// today's session. It doubles as the empty state for a brand-new account, so
/// the screen never opens on a wall of zeros.
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.deck,
    required this.dueCount,
    required this.firstRun,
  });

  final DeckNode deck;
  final int dueCount;
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _Panel(
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.softAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: context.onSoftAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    firstRun
                        ? 'لم تسجّل أي مراجعة بعد'
                        : '$dueCount بطاقة مستحقة اليوم',
                    style: context.texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstRun
                        ? 'أول مراجعة تمنحك 10 XP وتفتح شارة «الخطوة الأولى».'
                        : 'أكمل جلسة اليوم لتحافظ على سلسلتك.',
                    style: context.texts.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => openStudyMode(context, deck),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'راجع',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the dashboard says before there is anything to measure.
///
/// Two different empty states live here: a reader with decks and no sessions,
/// and a reader with no decks at all. The second one gets a button, because
/// telling someone to study when they own nothing is a dead end.
class _FirstRunPanel extends StatelessWidget {
  const _FirstRunPanel({required this.hasDeck});

  final bool hasDeck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.softAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasDeck
                        ? CupertinoIcons.chart_bar_alt_fill
                        : CupertinoIcons.rectangle_stack_badge_plus,
                    size: 20,
                    color: context.onSoftAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasDeck ? 'رحلتك تبدأ بأول مراجعة' : 'أنشئ مجموعتك الأولى',
                    style: context.texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasDeck
                  ? 'لم تُسجّل أي مراجعة بعد، لذا لا توجد سلسلة أيام ولا نسبة '
                        'تثبيت بعد. أنجز جلسة واحدة وستمتلئ هذه الصفحة بأرقامك '
                        'الحقيقية: نقاط الخبرة، وسلسلة الأيام، وخطة الأسبوع.'
                  : 'تحتاج مجموعة فيها بطاقات قبل أن تبدأ. أنشئ مجموعة، أضف '
                        'بطاقاتك، ثم عُد إلى هنا لمتابعة تقدّمك.',
              style: context.texts.bodySmall?.copyWith(
                fontSize: 11.5,
                height: 1.7,
              ),
            ),
            if (!hasDeck) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showCreateSheet(context),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('إنشاء مجموعة'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFFF9A3D), Color(0xFFE8590C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    CupertinoIcons.flame_fill,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'السلسلة الحالية',
                        style: context.texts.bodySmall?.copyWith(
                          fontSize: 10.5,
                        ),
                      ),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: summary.currentStreak),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder:
                            (BuildContext context, int value, Widget? child) {
                              return Text(
                                '$value',
                                style: TextStyle(
                                  fontFamily: 'ReadexPro',
                                  fontSize: 26,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: context.ink,
                                ),
                              );
                            },
                      ),
                      Text(
                        'يوم متتالٍ',
                        style: context.texts.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'أفضل سلسلة',
                      style: context.texts.bodySmall?.copyWith(fontSize: 10),
                    ),
                    Text(
                      '${summary.bestStreak}',
                      style: TextStyle(
                        fontFamily: 'ReadexPro',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.brandInk,
                      ),
                    ),
                    Text(
                      'يوم',
                      style: context.texts.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MonthCalendar(summary: summary),
          ],
        ),
      ),
    );
  }
}

/// The current month as a grid, with studied days filled in.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year, now.month, 1);
    final DateTime today = dayOf(now);
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // weekday is 1 for Monday and 7 for Sunday; the grid starts on Sunday.
    final int leading = first.weekday % 7;
    final int active = summary.activeDaysInMonth(now);

    final List<Widget> rows = <Widget>[];
    int cursor = 0;
    while (cursor < leading + daysInMonth) {
      final List<Widget> cells = <Widget>[];
      for (int column = 0; column < 7; column++) {
        final int cell = cursor + column;
        final int dayNumber = cell - leading + 1;
        if (cell >= leading + daysInMonth || dayNumber < 1) {
          cells.add(const Expanded(child: SizedBox(height: 34)));
        } else {
          final DateTime date = DateTime(now.year, now.month, dayNumber);
          cells.add(
            Expanded(
              child: _DayCell(
                day: dayNumber,
                active: summary.reviewsByDay.containsKey(date),
                isToday: date == today,
              ),
            ),
          );
        }
      }
      rows.add(Row(children: cells));
      cursor += 7;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${_months[now.month - 1]} ${now.year}',
              style: context.texts.bodySmall?.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.ink,
              ),
            ),
            const Spacer(),
            Text(
              '$active يوم نشاط',
              style: context.texts.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (final String day in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: context.texts.bodySmall?.copyWith(
                      fontSize: 9,
                      color: context.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        for (final Widget row in rows) row,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.active,
    required this.isToday,
  });

  final int day;
  final bool active;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent
            : context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(
                color: active ? AppColors.primary : context.brandInk,
                width: 1.5,
              )
            : null,
      ),
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 11,
          fontWeight: active || isToday ? FontWeight.w700 : FontWeight.w500,
          color: active
              ? AppColors.primary
              : (isToday ? context.ink : context.muted),
        ),
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<Achievement> badges = achievementsFor(summary);
    int unlocked = 0;
    for (final Achievement badge in badges) {
      if (badge.unlocked) {
        unlocked++;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 22),
        SectionHeader(
          title: 'الإنجازات',
          subtitle: '$unlocked من ${badges.length} شارة مفتوحة',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: badges.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              return _BadgeTile(
                achievement: badges[index],
                onTap: () => _showBadge(context, badges[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.achievement, required this.onTap});

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool open = achievement.unlocked;
    final Color ink = _badgeInk(context, achievement.color);
    return SizedBox(
      width: 92,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: open
                          ? achievement.color.withValues(
                              alpha: context.isDark ? 0.26 : 0.14,
                            )
                          : context.colors.surfaceContainerHighest,
                      border: Border.all(
                        color: open
                            ? ink.withValues(alpha: 0.45)
                            : context.hairline,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      achievement.icon,
                      size: 27,
                      color: open ? ink : context.muted.withValues(alpha: 0.55),
                    ),
                  ),
                  if (!open)
                    PositionedDirectional(
                      end: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: context.cardSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.hairline),
                        ),
                        child: Icon(
                          CupertinoIcons.lock_fill,
                          size: 10,
                          color: context.muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                achievement.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  fontWeight: open ? FontWeight.w700 : FontWeight.w500,
                  color: open ? context.ink : context.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows what a badge asks for and how far the learner has got.
Future<void> _showBadge(BuildContext context, Achievement achievement) {
  final Color ink = _badgeInk(context, achievement.color);
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
      contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      title: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: achievement.color.withValues(
                alpha: context.isDark ? 0.26 : 0.14,
              ),
            ),
            child: Icon(achievement.icon, size: 21, color: ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              achievement.title,
              style: const TextStyle(
                fontFamily: 'ReadexPro',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            achievement.requirement,
            style: context.texts.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: achievement.ratio,
            minHeight: 7,
            backgroundColor: context.colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(ink),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.unlocked
                ? 'مفتوحة'
                : '${achievement.progress} من ${achievement.target}',
            style: context.texts.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: achievement.unlocked ? ink : context.muted,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

class _RetentionCard extends StatelessWidget {
  const _RetentionCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'معدل التذكر',
          subtitle: 'الإجابات الصحيحة من كل مراجعاتك',
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Panel(
            child: summary.totalReviews == 0
                ? const _EmptyChart(
                    icon: CupertinoIcons.chart_pie,
                    text: 'لا توجد مراجعات بعد. عد عندما تبدأ.',
                  )
                : Row(
                    children: <Widget>[
                      SizedBox(
                        width: 116,
                        height: 116,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 42,
                                startDegreeOffset: -90,
                                sections: <PieChartSectionData>[
                                  PieChartSectionData(
                                    value: summary.correctReviews.toDouble(),
                                    color: _goodInk(context),
                                    radius: 13,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: summary.missedReviews.toDouble(),
                                    color: context.colors.outlineVariant,
                                    radius: 13,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: summary.retention,
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder:
                                  (
                                    BuildContext context,
                                    double value,
                                    Widget? child,
                                  ) {
                                    return Text(
                                      '${(value * 100).round()}%',
                                      style: TextStyle(
                                        fontFamily: 'ReadexPro',
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: context.ink,
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _LegendRow(
                              color: _goodInk(context),
                              label: 'صحيحة',
                              value: '${summary.correctReviews}',
                            ),
                            const SizedBox(height: 9),
                            _LegendRow(
                              color: context.colors.outlineVariant,
                              label: 'خاطئة',
                              value: '${summary.missedReviews}',
                            ),
                            const SizedBox(height: 9),
                            _LegendRow(
                              color: context.muted,
                              label: 'إجمالي المراجعات',
                              value: '${summary.totalReviews}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: context.texts.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'ReadexPro',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
        ),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final List<DueForecastDay> forecast;

  @override
  Widget build(BuildContext context) {
    int total = 0;
    for (final DueForecastDay day in forecast) {
      total += day.count;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'الأيام القادمة',
          subtitle: 'البطاقات المستحقة في الأسبوع القادم',
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Panel(
            child: forecast.isEmpty
                ? const _EmptyChart(
                    icon: CupertinoIcons.calendar,
                    text: 'لا توجد بطاقات مجدولة بعد.',
                  )
                : Column(
                    children: <Widget>[
                      SizedBox(
                        height: 146,
                        child: _ForecastBars(forecast: forecast),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Icon(
                            CupertinoIcons.calendar_today,
                            size: 12,
                            color: context.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              total == 0
                                  ? 'لا شيء مستحق خلال سبعة أيام.'
                                  : '$total بطاقة خلال سبعة أيام',
                              style: context.texts.bodySmall?.copyWith(
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ForecastBars extends StatelessWidget {
  const _ForecastBars({required this.forecast});

  final List<DueForecastDay> forecast;

  @override
  Widget build(BuildContext context) {
    double highest = 0;
    for (final DueForecastDay day in forecast) {
      if (day.count > highest) {
        highest = day.count.toDouble();
      }
    }
    final double maxY = math.max(4.0, highest * 1.2);
    final Color strong = context.isDark ? AppColors.accent : AppColors.primary;
    final Color soft = AppColors.accent.withValues(
      alpha: context.isDark ? 0.3 : 0.55,
    );
    final Color track = context.colors.surfaceContainerHighest;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.round();
                if (index < 0 || index >= forecast.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    _dayLabel(forecast, index),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: index == 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: index == 0 ? context.ink : context.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int index = 0; index < forecast.length; index++)
            BarChartGroupData(
              x: index,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: forecast[index].count.toDouble(),
                  width: 16,
                  color: index == 0 ? strong : soft,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: track,
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final DateTime today = dayOf(DateTime.now());
    final DateTime weekStart = addDays(today, -(today.weekday % 7));
    final DateTime start = addDays(weekStart, -77);

    int highest = 1;
    for (final int value in summary.reviewsByDay.values) {
      if (value > highest) {
        highest = value;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'النشاط',
          subtitle: 'كل يوم راجعته في آخر 12 أسبوعاً',
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int weekday = 0; weekday < 7; weekday++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              width: 22,
                              child: Text(
                                weekday == 0 || weekday == 2 || weekday == 4
                                    ? _weekdays[weekday]
                                    : '',
                                style: context.texts.bodySmall?.copyWith(
                                  fontSize: 8,
                                  color: context.muted,
                                ),
                              ),
                            ),
                            for (int week = 0; week < 12; week++)
                              Padding(
                                padding: const EdgeInsets.all(1.5),
                                child: _HeatCell(
                                  date: addDays(start, week * 7 + weekday),
                                  count:
                                      summary.reviewsByDay[addDays(
                                        start,
                                        week * 7 + weekday,
                                      )] ??
                                      0,
                                  highest: highest,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text(
                      'أقل',
                      style: context.texts.bodySmall?.copyWith(fontSize: 9),
                    ),
                    const SizedBox(width: 6),
                    for (int step = 1; step <= 4; step++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 3),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _heatColor(context, step, 4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    const SizedBox(width: 3),
                    Text(
                      'أكثر',
                      style: context.texts.bodySmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.date,
    required this.count,
    required this.highest,
  });

  final DateTime date;
  final int count;
  final int highest;

  @override
  Widget build(BuildContext context) {
    // Four steps relative to the busiest day, so the ramp adapts to how much
    // this learner actually reviews instead of a fixed scale nobody reaches.
    final int step = count == 0 ? 0 : math.max(1, (count / highest * 4).ceil());
    return Tooltip(
      message: '${date.day}/${date.month} · $count مراجعة',
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: _heatColor(context, step, 4),
          borderRadius: BorderRadius.circular(3.5),
        ),
      ),
    );
  }
}

Color _heatColor(BuildContext context, int step, int steps) {
  if (step <= 0) {
    return context.colors.surfaceContainerHighest;
  }
  final double t = math.min(1.0, step / steps);
  if (context.isDark) {
    return Color.lerp(
      AppColors.darkSurfaceHigh,
      AppColors.accent,
      0.28 + 0.72 * t,
    )!;
  }
  return Color.lerp(AppColors.accentSoft, AppColors.primary, 0.3 + 0.7 * t)!;
}

/// The shared card shell for every chart section: white in light mode, a
/// raised surface in dark mode, with a hairline that survives both.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.hairline),
      ),
      child: child,
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 26, color: context.muted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// 2340 -> "2,340".
String _thousands(int value) {
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      out.write(',');
    }
    out.write(digits[index]);
  }
  return value < 0 ? '-$out' : out.toString();
}

/// Badge hues are mid-tone so they read on white; on the dark page they are
/// lifted toward white instead of being replaced, which keeps each badge
/// recognisably its own colour.
Color _badgeInk(BuildContext context, Color base) =>
    context.isDark ? Color.lerp(base, Colors.white, 0.45)! : base;

/// The colour that means "recalled it" on charts.
Color _goodInk(BuildContext context) =>
    context.isDark ? AppColors.accent : AppColors.primary;

String _dayLabel(List<DueForecastDay> forecast, int index) {
  if (index <= 0) {
    return 'اليوم';
  }
  if (index == 1) {
    return 'غداً';
  }
  return _weekdays[forecast[index].day.weekday % 7];
}
