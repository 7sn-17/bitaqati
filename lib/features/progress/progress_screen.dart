import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ReviewActivityDay>> activityAsync = ref.watch(
      reviewActivityProvider,
    );
    final List<ReviewActivityDay> activity =
        activityAsync.valueOrNull ?? const <ReviewActivityDay>[];
    final int currentStreak = ref.watch(streakProvider).valueOrNull ?? 0;
    final List<DueForecastDay> forecast =
        ref.watch(dueForecastProvider).valueOrNull ?? const <DueForecastDay>[];
    final DueTotals due = ref.watch(dueTotalsProvider);
    final DeckNode? todayDeck = ref.watch(todayReviewDeckProvider);
    final List<DeckNode> decks = ref.watch(allDecksProvider);
    final int reviews = activity.fold<int>(
      0,
      (int sum, ReviewActivityDay day) => sum + day.reviews,
    );
    final int correct = activity.fold<int>(
      0,
      (int sum, ReviewActivityDay day) => sum + day.correct,
    );
    final int retention = reviews == 0 ? 0 : (correct / reviews * 100).round();
    final int longest = _longestStreak(activity);
    final int activeDays = activity.where((day) => day.reviews > 0).length;
    final String streakValue = currentStreak == 2
        ? 'يومان'
        : '$currentStreak';
    final String? streakSuffix = currentStreak == 2
        ? null
        : _dayWord(currentStreak);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 118),
        children: <Widget>[
          Padding(
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.chart_bar_fill, size: 21),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (activityAsync.isLoading && activity.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (activity.isEmpty)
            _EmptyProgress(
              due: due.total,
              onReview: todayDeck == null
                  ? null
                  : () => context.push('/review/${todayDeck.id}'),
              onBrowse: () => context.go('/decks'),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _BigStat(
                      label: 'نسبة التذكر',
                      value: '$retention%',
                      dark: true,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _BigStat(
                      label: 'السلسلة الحالية',
                      value: streakValue,
                      suffix: streakSuffix,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _SmallStat(
                      label: 'مراجعات',
                      value: '$reviews',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallStat(
                      label: 'أيام نشطة',
                      value: '$activeDays',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallStat(
                      label: 'أطول سلسلة',
                      value: '$longest',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'نشاط آخر 12 أسبوعاً'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Heatmap(activity: activity),
            ),
            const SizedBox(height: 22),
            const SectionHeader(
              title: 'المستحقة خلال 7 أيام',
              subtitle: 'خطّط وقتك قبل أن تتراكم البطاقات',
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ForecastChart(forecast: forecast),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'نسبة التذكر حسب المجموعة'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DeckRetention(decks: decks),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ReviewNowCard(
                due: due,
                deck: todayDeck,
                onReview: todayDeck == null
                    ? null
                    : () => context.push('/review/${todayDeck.id}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _longestStreak(List<ReviewActivityDay> activity) {
    if (activity.isEmpty) {
      return 0;
    }
    final List<DateTime> days = activity
        .where((ReviewActivityDay day) => day.reviews > 0)
        .map((ReviewActivityDay day) => _dateOnly(day.day))
        .toSet()
        .toList()
      ..sort();
    if (days.isEmpty) {
      return 0;
    }
    int longest = 1;
    int run = 1;
    for (int index = 1; index < days.length; index++) {
      if (days[index].difference(days[index - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      longest = math.max(longest, run);
    }
    return longest;
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress({
    required this.due,
    required this.onReview,
    required this.onBrowse,
  });

  final int due;
  final VoidCallback? onReview;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.primary, Color(0xFF2D5410)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.chart_bar_alt_fill,
                size: 36,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'رحلة الإتقان تبدأ بأول مراجعة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ReadexPro',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              due > 0
                  ? 'لديك $due بطاقة مستحقة الآن. راجعها وستظهر هنا '
                        'نسبة تذكرك وخريطة نشاطك.'
                  : 'أضف بطاقات وابدأ المراجعة، ثم ستجد هنا نسبة تذكرك '
                        'وسلسلتك اليومية وخريطة نشاطك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 18),
            if (onReview != null)
              FilledButton.icon(
                onPressed: onReview,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(CupertinoIcons.play_fill, size: 16),
                label: const Text('ابدأ المراجعة'),
              )
            else
              OutlinedButton.icon(
                onPressed: onBrowse,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
                icon: const Icon(CupertinoIcons.folder, size: 16),
                label: const Text('تصفّح مجموعاتي'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    this.suffix,
    this.dark = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color background = dark
        ? AppColors.primary
        : context.colors.surfaceContainerHighest;
    final Color ink = dark ? Colors.white : context.colors.onSurface;
    final Color valueColor = dark ? AppColors.accent : ink;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: dark
                  ? const Color(0xFFCFE8C0)
                  : context.texts.bodySmall?.color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (suffix != null) ...<Widget>[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix!,
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFCFE8C0)
                          : context.texts.bodySmall?.color,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(label, style: context.texts.bodySmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.activity});

  final List<ReviewActivityDay> activity;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> counts = <String, int>{
      for (final ReviewActivityDay day in activity)
        _dayKey(day.day): day.reviews,
    };
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start = today.subtract(const Duration(days: 83));
    final int maxCount = counts.values.fold<int>(
      1,
      (int best, int value) => math.max(best, value),
    );
    final Color empty = context.colors.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (int weekday = 0; weekday < 7; weekday++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  for (int week = 0; week < 12; week++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2, right: 2),
                        child: _HeatCell(
                          date: start.add(
                            Duration(days: week * 7 + weekday),
                          ),
                          count:
                              counts[_dayKey(
                                start.add(Duration(days: week * 7 + weekday)),
                              )] ??
                              0,
                          maxCount: maxCount,
                          empty: empty,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              Text(
                _shortDate(start),
                style: context.texts.bodySmall?.copyWith(fontSize: 9.5),
              ),
              const Spacer(),
              Text(
                'اليوم',
                style: context.texts.bodySmall?.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.date,
    required this.count,
    required this.maxCount,
    required this.empty,
  });

  final DateTime date;
  final int count;
  final int maxCount;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (count == 0) {
      color = empty;
    } else if (count <= maxCount / 3) {
      color = AppColors.accentSoft;
    } else if (count <= maxCount * 2 / 3) {
      color = AppColors.accent.withValues(alpha: 0.65);
    } else {
      color = AppColors.primary;
    }
    return Tooltip(
      message: '${_shortDate(date)} · $count مراجعة',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.forecast});

  final List<DueForecastDay> forecast;

  @override
  Widget build(BuildContext context) {
    if (forecast.isEmpty || forecast.every((day) => day.count == 0)) {
      return SurfaceCard(
        child: Row(
          children: <Widget>[
            const Icon(
              CupertinoIcons.checkmark_seal,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'لا بطاقات مستحقة خلال الأسبوع القادم. استمتع بوقتك!',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    final int max = forecast.fold<int>(
      1,
      (int best, DueForecastDay day) => math.max(best, day.count),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: SizedBox(
        height: 145,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (int index = 0; index < forecast.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${forecast[index].count}',
                        style: context.texts.bodySmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor:
                                forecast[index].count == 0
                                ? 0.03
                                : forecast[index].count / max,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? AppColors.accent
                                    : AppColors.primary.withValues(
                                        alpha: 0.25,
                                      ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        index == 0
                            ? 'اليوم'
                            : index == 1
                            ? 'غداً'
                            : _weekday(forecast[index].day),
                        style: context.texts.bodySmall?.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeckRetention extends StatelessWidget {
  const _DeckRetention({required this.decks});

  final List<DeckNode> decks;

  @override
  Widget build(BuildContext context) {
    final List<DeckNode> reviewed = decks
        .where((DeckNode deck) => deck.reviewCount > 0)
        .toList()
      ..sort(
        (DeckNode a, DeckNode b) => b.retention.compareTo(a.retention),
      );
    if (reviewed.isEmpty) {
      return SurfaceCard(
        child: Text(
          'ستظهر هنا نسبة التذكر لكل مجموعة بعد أن تراجع بطاقاتها.',
          style: context.texts.bodySmall,
        ),
      );
    }
    return SurfaceCard(
      child: Column(
        children: <Widget>[
          for (int index = 0; index < reviewed.length; index++) ...<Widget>[
            if (index > 0)
              Divider(
                height: 18,
                color: context.colors.outlineVariant.withValues(alpha: 0.5),
              ),
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: reviewed[index].color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    reviewed[index].icon,
                    size: 17,
                    color: reviewed[index].color,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        reviewed[index].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: reviewed[index].retention / 100,
                          minHeight: 5,
                          backgroundColor:
                              context.colors.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            reviewed[index].color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '${reviewed[index].retention.round()}%',
                  style: context.texts.labelLarge?.copyWith(
                    fontSize: 12,
                    color: reviewed[index].color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewNowCard extends StatelessWidget {
  const _ReviewNowCard({
    required this.due,
    required this.deck,
    required this.onReview,
  });

  final DueTotals due;
  final DeckNode? deck;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final bool empty = due.total == 0 || deck == null;
    return SurfaceCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: empty ? context.softAccent : AppColors.warning,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              empty
                  ? CupertinoIcons.checkmark_seal
                  : CupertinoIcons.clock_fill,
              color: empty ? context.onSoftAccent : AppColors.warningInk,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  empty ? 'لا شيء مستحق الآن' : '${due.total} بطاقة بانتظارك',
                  style: context.texts.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  empty
                      ? 'عد لاحقاً أو أضف بطاقات جديدة.'
                      : '${due.fresh} جديدة · ${due.learning} تعلّم · '
                            '${due.review} مراجعة',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
          if (!empty)
            FilledButton(
              onPressed: onReview,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('راجع'),
            ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

String _dayKey(DateTime value) => _dateOnly(value).toIso8601String();

String _shortDate(DateTime value) => '${value.day}/${value.month}';

String _weekday(DateTime value) {
  const List<String> names = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  return names[value.weekday - 1];
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
