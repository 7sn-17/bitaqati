import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'models.dart';

/// A calendar day with the time stripped, so two instants on the same date
/// compare equal and can be used as map keys.
DateTime dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

/// Shifts [day] by [days] calendar days.
///
/// Built from the date fields rather than [Duration], because adding 24 hours
/// across a daylight-saving change lands on 23:00 of the previous day and the
/// whole calendar would shift by one column.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// What one action is worth, in XP.
abstract final class XpRules {
  /// Every answer, right or wrong: showing up counts.
  static const int perReview = 10;

  /// An answer the learner actually recalled. The review screen writes 2 and
  /// up for a successful recall, and test mode writes 3 for a correct choice,
  /// so both paths earn this bonus without a separate counter.
  static const int perCorrectReview = 5;

  /// A deck is a bigger commitment than a single answer.
  static const int perDeck = 50;
}

/// Levels get more expensive as they climb.
///
/// Level *n* starts at `50 * n * (n - 1)` XP: 0, 100, 300, 600, 1000, 1500 …
/// At ten XP a review that is roughly a review a day to reach level five in a
/// month, and a genuine long-term goal beyond that.
abstract final class LevelCurve {
  static const int _step = 50;

  /// Total XP needed to reach [level]. Level 1 starts at zero.
  static int totalXpFor(int level) =>
      level <= 1 ? 0 : _step * level * (level - 1);

  /// The highest level [xp] has already paid for.
  static int levelForXp(int xp) {
    int level = 1;
    while (totalXpFor(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// The Arabic rank shown beside the level number.
  static String titleFor(int level) {
    if (level >= 20) {
      return 'أسطورة';
    }
    if (level >= 15) {
      return 'حكيم';
    }
    if (level >= 10) {
      return 'خبير';
    }
    if (level >= 7) {
      return 'متمرّس';
    }
    if (level >= 5) {
      return 'مجتهد';
    }
    if (level >= 3) {
      return 'متعلّم';
    }
    return 'مبتدئ';
  }
}

/// Everything the progress tab draws, computed once from real database rows.
///
/// Nothing here is stored: XP, level, streaks and badges are all derived from
/// `review_logs` (through [ReviewActivityDay]) and the deck table, so the
/// numbers can never drift from the history that produced them.
@immutable
class ProgressSummary {
  const ProgressSummary({
    required this.totalReviews,
    required this.correctReviews,
    required this.deckCount,
    required this.cardCount,
    required this.currentStreak,
    required this.bestStreak,
    required this.todayReviews,
    required this.weekReviews,
    required this.activeDays,
    required this.reviewsByDay,
    required this.xp,
  });

  factory ProgressSummary.fromActivity({
    required List<ReviewActivityDay> activity,
    required int deckCount,
    required int cardCount,
    required DateTime now,
  }) {
    final Map<DateTime, int> byDay = <DateTime, int>{};
    int reviews = 0;
    int correct = 0;
    for (final ReviewActivityDay day in activity) {
      reviews += day.reviews;
      correct += day.correct;
      if (day.reviews > 0) {
        byDay[dayOf(day.day)] = day.reviews;
      }
    }
    final DateTime today = dayOf(now);
    int week = 0;
    for (int back = 0; back < 7; back++) {
      week += byDay[addDays(today, -back)] ?? 0;
    }
    final Set<DateTime> days = byDay.keys.toSet();
    return ProgressSummary(
      totalReviews: reviews,
      correctReviews: correct,
      deckCount: deckCount,
      cardCount: cardCount,
      currentStreak: _currentStreak(days, today),
      bestStreak: _bestStreak(days),
      todayReviews: byDay[today] ?? 0,
      weekReviews: week,
      activeDays: byDay.length,
      reviewsByDay: byDay,
      xp:
          reviews * XpRules.perReview +
          correct * XpRules.perCorrectReview +
          deckCount * XpRules.perDeck,
    );
  }

  final int totalReviews;
  final int correctReviews;
  final int deckCount;
  final int cardCount;
  final int currentStreak;
  final int bestStreak;
  final int todayReviews;
  final int weekReviews;
  final int activeDays;

  /// Reviews per calendar day. Days without a review are absent, not zero.
  final Map<DateTime, int> reviewsByDay;

  final int xp;

  int get missedReviews => totalReviews - correctReviews;

  /// 0..1. Uses the same definition of "correct" as the heatmap and the deck
  /// statistics, so every screen agrees on what a successful review is.
  double get retention =>
      totalReviews == 0 ? 0.0 : correctReviews / totalReviews;

  int get level => LevelCurve.levelForXp(xp);

  String get levelTitle => LevelCurve.titleFor(level);

  int get levelFloorXp => LevelCurve.totalXpFor(level);

  int get nextLevelXp => LevelCurve.totalXpFor(level + 1);

  int get xpIntoLevel => xp - levelFloorXp;

  int get levelSpan => nextLevelXp - levelFloorXp;

  /// 0..1 progress from the current level to the next one.
  double get levelProgress => levelSpan <= 0
      ? 0.0
      : math.min(1.0, math.max(0.0, xpIntoLevel / levelSpan));

  /// How many days this month carried at least one review.
  int activeDaysInMonth(DateTime month) {
    int count = 0;
    final int days = DateTime(month.year, month.month + 1, 0).day;
    for (int day = 1; day <= days; day++) {
      if (reviewsByDay.containsKey(DateTime(month.year, month.month, day))) {
        count++;
      }
    }
    return count;
  }
}

int _currentStreak(Set<DateTime> days, DateTime today) {
  DateTime cursor = today;
  if (!days.contains(cursor)) {
    cursor = addDays(today, -1);
  }
  int streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

int _bestStreak(Set<DateTime> days) {
  if (days.isEmpty) {
    return 0;
  }
  final List<DateTime> sorted = days.toList()..sort();
  int best = 1;
  int run = 1;
  for (int index = 1; index < sorted.length; index++) {
    if (addDays(sorted[index - 1], 1) == sorted[index]) {
      run++;
      if (run > best) {
        best = run;
      }
    } else {
      run = 1;
    }
  }
  return best;
}

/// One badge, with the live progress that decides whether it is earned.
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.requirement,
    required this.icon,
    required this.color,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;

  /// What the learner has to do, in one sentence.
  final String requirement;

  final IconData icon;
  final Color color;
  final int progress;
  final int target;

  bool get unlocked => progress >= target;

  /// 0..1, clamped so an over-achieved badge still draws a full bar.
  double get ratio => target <= 0 ? 1.0 : math.min(1.0, progress / target);
}

/// The badge shelf, newest milestone last.
///
/// Streak badges read [ProgressSummary.bestStreak] rather than the current
/// streak: a badge that disappears the morning after a missed day would be a
/// punishment, not a reward.
List<Achievement> achievementsFor(ProgressSummary summary) {
  final int retentionPercent = (summary.retention * 100).round();
  return <Achievement>[
    Achievement(
      id: 'first_review',
      title: 'الخطوة الأولى',
      requirement: 'أكمل مراجعة واحدة.',
      icon: CupertinoIcons.sparkles,
      color: const Color(0xFF2E7D6B),
      progress: summary.totalReviews,
      target: 1,
    ),
    Achievement(
      id: 'hundred',
      title: 'مئة مراجعة',
      requirement: 'أكمل 100 مراجعة.',
      icon: CupertinoIcons.checkmark_seal,
      color: const Color(0xFF0B4C72),
      progress: summary.totalReviews,
      target: 100,
    ),
    Achievement(
      id: 'master',
      title: 'المتمكّن',
      requirement: 'أكمل 1000 مراجعة.',
      icon: CupertinoIcons.rosette,
      color: const Color(0xFF6B5B95),
      progress: summary.totalReviews,
      target: 1000,
    ),
    Achievement(
      id: 'week_streak',
      title: 'مثابر',
      requirement: 'راجع سبعة أيام متتالية.',
      icon: CupertinoIcons.flame,
      color: const Color(0xFFE8590C),
      progress: summary.bestStreak,
      target: 7,
    ),
    Achievement(
      id: 'month_streak',
      title: 'لا ينكسر',
      requirement: 'راجع ثلاثين يوماً متتالياً.',
      icon: CupertinoIcons.flame_fill,
      color: const Color(0xFFCB272F),
      progress: summary.bestStreak,
      target: 30,
    ),
    Achievement(
      id: 'perfectionist',
      title: 'المتقن',
      requirement: 'تذكّر 95% أو أكثر بعد 100 مراجعة.',
      icon: CupertinoIcons.scope,
      color: const Color(0xFF4E7A2A),
      progress: summary.totalReviews >= 100 ? retentionPercent : 0,
      target: 95,
    ),
    Achievement(
      id: 'creator',
      title: 'المنشئ',
      requirement: 'أنشئ خمس مجموعات.',
      icon: CupertinoIcons.square_stack_3d_up,
      color: const Color(0xFFE0A200),
      progress: summary.deckCount,
      target: 5,
    ),
    Achievement(
      id: 'legend',
      title: 'أسطورة',
      requirement: 'اصل إلى المستوى العاشر.',
      icon: CupertinoIcons.star_circle_fill,
      color: const Color(0xFF0F766E),
      progress: summary.level,
      target: 10,
    ),
  ];
}
