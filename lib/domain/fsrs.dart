import 'dart:math' as math;

/// FSRS-6 scheduler.
///
/// This is a faithful Dart port of the Open Spaced Repetition FSRS-6 scheduler
/// (default 21 weights, long-term and short-term stability, mean-reverting
/// difficulty, learning/relearning steps and optional interval fuzzing).
///
/// The scheduler is pure: it never touches storage or Flutter. That keeps the
/// most important logic in the app testable on its own.
enum FsrsRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const FsrsRating(this.value);

  final int value;
}

enum FsrsState { newCard, learning, review, relearning }

/// Default FSRS-6 weights published by Open Spaced Repetition.
const List<double> defaultFsrsParameters = <double>[
  0.212,
  1.2931,
  2.3065,
  8.2956,
  6.4133,
  0.8334,
  3.0194,
  0.001,
  1.8722,
  0.1666,
  0.796,
  1.4835,
  0.0614,
  0.2629,
  1.6483,
  0.6014,
  1.8729,
  0.5425,
  0.0912,
  0.0658,
  0.1542,
];

const List<Duration> defaultLearningSteps = <Duration>[
  Duration(minutes: 1),
  Duration(minutes: 10),
];

const List<Duration> defaultRelearningSteps = <Duration>[Duration(minutes: 10)];

const double minimumStability = 0.001;
const double minimumDifficulty = 1.0;
const double maximumDifficulty = 10.0;

/// Immutable scheduling state for one card.
class FsrsCard {
  const FsrsCard({
    required this.due,
    this.state = FsrsState.newCard,
    this.stability,
    this.difficulty,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    this.learningStep = 0,
    this.reps = 0,
    this.lapses = 0,
    this.lastReview,
  });

  factory FsrsCard.newCard(DateTime createdAt) {
    return FsrsCard(due: createdAt.toUtc());
  }

  final FsrsState state;
  final DateTime due;
  final double? stability;
  final double? difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final int learningStep;
  final int reps;
  final int lapses;
  final DateTime? lastReview;

  bool get isNew => state == FsrsState.newCard || reps == 0;
  bool get isDue => due.isBefore(DateTime.now().toUtc());
  bool get isLearning =>
      state == FsrsState.learning || state == FsrsState.relearning;

  FsrsCard copyWith({
    FsrsState? state,
    DateTime? due,
    double? stability,
    double? difficulty,
    int? elapsedDays,
    int? scheduledDays,
    int? learningStep,
    int? reps,
    int? lapses,
    DateTime? lastReview,
    bool clearLastReview = false,
  }) {
    return FsrsCard(
      state: state ?? this.state,
      due: due ?? this.due,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      learningStep: learningStep ?? this.learningStep,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReview: clearLastReview ? null : (lastReview ?? this.lastReview),
    );
  }
}

class FsrsReviewLog {
  const FsrsReviewLog({
    required this.rating,
    required this.reviewedAt,
    required this.previousState,
    required this.nextState,
    required this.scheduledDays,
    required this.stability,
    required this.difficulty,
    this.elapsedMs,
  });

  final FsrsRating rating;
  final DateTime reviewedAt;
  final FsrsState previousState;
  final FsrsState nextState;
  final int scheduledDays;
  final double stability;
  final double difficulty;
  final int? elapsedMs;
}

class FsrsReviewResult {
  const FsrsReviewResult({
    required this.card,
    required this.log,
    required this.interval,
  });

  final FsrsCard card;
  final FsrsReviewLog log;
  final Duration interval;
}

class FsrsPreview {
  const FsrsPreview({
    required this.rating,
    required this.due,
    required this.interval,
    required this.state,
    required this.stability,
    required this.difficulty,
  });

  final FsrsRating rating;
  final DateTime due;
  final Duration interval;
  final FsrsState state;
  final double stability;
  final double difficulty;
}

/// Real FSRS-6 scheduler. No simulated scores, no hard-coded intervals.
class FsrsScheduler {
  FsrsScheduler({
    this.parameters = defaultFsrsParameters,
    this.desiredRetention = 0.90,
    this.learningSteps = defaultLearningSteps,
    this.relearningSteps = defaultRelearningSteps,
    this.maximumInterval = 36500,
    this.enableFuzzing = false,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    assert(parameters.length == 21, 'FSRS-6 requires 21 weights');
    assert(desiredRetention > 0 && desiredRetention < 1);
    _decay = -parameters[20];
    _factor = math.pow(0.9, 1 / _decay).toDouble() - 1;
  }

  final List<double> parameters;
  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumInterval;
  final bool enableFuzzing;
  final math.Random _random;

  late final double _decay;
  late final double _factor;

  /// Probability that the card is still remembered at [at].
  double retrievability(FsrsCard card, [DateTime? at]) {
    final DateTime? lastReview = card.lastReview;
    final double? stability = card.stability;
    if (lastReview == null || stability == null || stability <= 0) {
      return 0;
    }
    final DateTime now = (at ?? DateTime.now()).toUtc();
    final int elapsedDays = math.max(
      0,
      now.difference(lastReview.toUtc()).inDays,
    );
    return math
        .pow(1 + _factor * elapsedDays / stability, _decay)
        .toDouble()
        .clamp(0.0, 1.0);
  }

  /// Returns the four possible outcomes for the rating buttons.
  Map<FsrsRating, FsrsPreview> preview(FsrsCard card, DateTime at) {
    final DateTime reviewedAt = at.toUtc();
    return <FsrsRating, FsrsPreview>{
      for (final FsrsRating rating in FsrsRating.values)
        rating: _previewOne(card, rating, reviewedAt),
    };
  }

  FsrsReviewResult review(
    FsrsCard card,
    FsrsRating rating,
    DateTime reviewedAt, {
    int? elapsedMs,
  }) {
    return _apply(
      card,
      rating,
      reviewedAt.toUtc(),
      elapsedMs: elapsedMs,
      countReview: true,
      applyFuzzing: enableFuzzing,
    );
  }

  FsrsPreview _previewOne(
    FsrsCard card,
    FsrsRating rating,
    DateTime reviewedAt,
  ) {
    final FsrsReviewResult result = _apply(
      card,
      rating,
      reviewedAt,
      countReview: false,
      applyFuzzing: false,
    );
    return FsrsPreview(
      rating: rating,
      due: result.card.due,
      interval: result.interval,
      state: result.card.state,
      stability: result.card.stability ?? 0,
      difficulty: result.card.difficulty ?? 0,
    );
  }

  FsrsReviewResult _apply(
    FsrsCard original,
    FsrsRating rating,
    DateTime reviewedAt, {
    required bool countReview,
    required bool applyFuzzing,
    int? elapsedMs,
  }) {
    final FsrsCard normalized = original.state == FsrsState.newCard
        ? original.copyWith(state: FsrsState.learning, learningStep: 0)
        : original;

    final FsrsState previousState = original.state;
    final int? daysSinceLastReview = normalized.lastReview == null
        ? null
        : math.max(
            0,
            reviewedAt.difference(normalized.lastReview!.toUtc()).inDays,
          );

    final _WorkingCard working = switch (normalized.state) {
      FsrsState.newCard => _WorkingCard.from(normalized),
      FsrsState.learning => _reviewLearning(
        card: normalized,
        rating: rating,
        reviewedAt: reviewedAt,
        daysSinceLastReview: daysSinceLastReview,
      ),
      FsrsState.review => _reviewReview(
        card: normalized,
        rating: rating,
        reviewedAt: reviewedAt,
        daysSinceLastReview: daysSinceLastReview,
      ),
      FsrsState.relearning => _reviewRelearning(
        card: normalized,
        rating: rating,
        reviewedAt: reviewedAt,
        daysSinceLastReview: daysSinceLastReview,
      ),
    };

    FsrsCard card = working.toCard().copyWith(
      lastReview: reviewedAt,
      elapsedDays: daysSinceLastReview ?? 0,
    );

    if (applyFuzzing && card.state == FsrsState.review) {
      final int fuzzedDays = _fuzzDays(card.scheduledDays);
      if (fuzzedDays != card.scheduledDays) {
        card = card.copyWith(
          scheduledDays: fuzzedDays,
          due: reviewedAt.add(Duration(days: fuzzedDays)),
        );
      }
    }

    final Duration interval = card.due.difference(reviewedAt);
    final FsrsCard finalCard = countReview
        ? card.copyWith(
            reps: card.reps + 1,
            lapses:
                card.lapses +
                (previousState == FsrsState.review && rating == FsrsRating.again
                    ? 1
                    : 0),
          )
        : card;

    return FsrsReviewResult(
      card: finalCard,
      log: FsrsReviewLog(
        rating: rating,
        reviewedAt: reviewedAt,
        previousState: previousState,
        nextState: finalCard.state,
        scheduledDays: finalCard.scheduledDays,
        stability: finalCard.stability ?? 0,
        difficulty: finalCard.difficulty ?? 0,
        elapsedMs: elapsedMs,
      ),
      interval: interval,
    );
  }

  // The public methods above are deliberately small. The three review methods
  // below mirror the FSRS-6 reference implementation.
  _WorkingCard _reviewLearning({
    required FsrsCard card,
    required FsrsRating rating,
    required DateTime reviewedAt,
    required int? daysSinceLastReview,
  }) {
    final _WorkingCard working = _WorkingCard.from(card);
    if (working.stability == null || working.difficulty == null) {
      working.stability = _initialStability(rating);
      working.difficulty = _initialDifficulty(rating, clamp: true);
    } else if (daysSinceLastReview != null && daysSinceLastReview < 1) {
      working.stability = _shortTermStability(
        stability: working.stability!,
        rating: rating,
      );
      working.difficulty = _nextDifficulty(
        difficulty: working.difficulty!,
        rating: rating,
      );
    } else {
      working.stability = _nextStability(
        difficulty: working.difficulty!,
        stability: working.stability!,
        retrievability: _retrievabilityFor(
          stability: working.stability!,
          lastReview: card.lastReview,
          reviewedAt: reviewedAt,
        ),
        rating: rating,
      );
      working.difficulty = _nextDifficulty(
        difficulty: working.difficulty!,
        rating: rating,
      );
    }

    if (learningSteps.isEmpty ||
        (working.step >= learningSteps.length && rating != FsrsRating.again)) {
      working.state = FsrsState.review;
      working.step = 0;
      final int nextDays = _nextIntervalDays(working.stability!);
      working.scheduledDays = nextDays;
      working.due = reviewedAt.add(Duration(days: nextDays));
    } else {
      _applyLearningStep(
        working: working,
        steps: learningSteps,
        rating: rating,
        reviewedAt: reviewedAt,
      );
    }
    return working;
  }

  _WorkingCard _reviewReview({
    required FsrsCard card,
    required FsrsRating rating,
    required DateTime reviewedAt,
    required int? daysSinceLastReview,
  }) {
    final _WorkingCard working = _WorkingCard.from(card);
    final double stability = working.stability!;
    final double difficulty = working.difficulty!;
    if (daysSinceLastReview != null && daysSinceLastReview < 1) {
      working.stability = _shortTermStability(
        stability: stability,
        rating: rating,
      );
    } else {
      working.stability = _nextStability(
        difficulty: difficulty,
        stability: stability,
        retrievability: _retrievabilityFor(
          stability: stability,
          lastReview: card.lastReview,
          reviewedAt: reviewedAt,
        ),
        rating: rating,
      );
    }
    working.difficulty = _nextDifficulty(
      difficulty: difficulty,
      rating: rating,
    );

    if (rating == FsrsRating.again && relearningSteps.isNotEmpty) {
      working.state = FsrsState.relearning;
      working.step = 0;
      working.scheduledDays = 0;
      working.due = reviewedAt.add(relearningSteps.first);
    } else {
      final int nextDays = _nextIntervalDays(working.stability!);
      working.state = FsrsState.review;
      working.scheduledDays = nextDays;
      working.due = reviewedAt.add(Duration(days: nextDays));
    }
    return working;
  }

  _WorkingCard _reviewRelearning({
    required FsrsCard card,
    required FsrsRating rating,
    required DateTime reviewedAt,
    required int? daysSinceLastReview,
  }) {
    final _WorkingCard working = _WorkingCard.from(card);
    final double stability = working.stability!;
    final double difficulty = working.difficulty!;
    if (daysSinceLastReview != null && daysSinceLastReview < 1) {
      working.stability = _shortTermStability(
        stability: stability,
        rating: rating,
      );
      working.difficulty = _nextDifficulty(
        difficulty: difficulty,
        rating: rating,
      );
    } else {
      working.stability = _nextStability(
        difficulty: difficulty,
        stability: stability,
        retrievability: _retrievabilityFor(
          stability: stability,
          lastReview: card.lastReview,
          reviewedAt: reviewedAt,
        ),
        rating: rating,
      );
      working.difficulty = _nextDifficulty(
        difficulty: difficulty,
        rating: rating,
      );
    }

    if (relearningSteps.isEmpty ||
        (working.step >= relearningSteps.length &&
            rating != FsrsRating.again)) {
      final int nextDays = _nextIntervalDays(working.stability!);
      working.state = FsrsState.review;
      working.step = 0;
      working.scheduledDays = nextDays;
      working.due = reviewedAt.add(Duration(days: nextDays));
    } else {
      _applyLearningStep(
        working: working,
        steps: relearningSteps,
        rating: rating,
        reviewedAt: reviewedAt,
      );
    }
    return working;
  }

  void _applyLearningStep({
    required _WorkingCard working,
    required List<Duration> steps,
    required FsrsRating rating,
    required DateTime reviewedAt,
  }) {
    switch (rating) {
      case FsrsRating.again:
        working.step = 0;
        working.scheduledDays = 0;
        working.due = reviewedAt.add(steps[0]);
      case FsrsRating.hard:
        if (working.step == 0 && steps.length == 1) {
          working.due = reviewedAt.add(
            Duration(milliseconds: (steps[0].inMilliseconds * 1.5).round()),
          );
        } else if (working.step == 0 && steps.length >= 2) {
          working.due = reviewedAt.add(
            Duration(
              milliseconds:
                  ((steps[0].inMilliseconds + steps[1].inMilliseconds) / 2)
                      .round(),
            ),
          );
        } else {
          working.due = reviewedAt.add(steps[working.step]);
        }
        working.scheduledDays = 0;
      case FsrsRating.good:
        if (working.step + 1 == steps.length) {
          final int nextDays = _nextIntervalDays(working.stability!);
          working.state = FsrsState.review;
          working.step = 0;
          working.scheduledDays = nextDays;
          working.due = reviewedAt.add(Duration(days: nextDays));
        } else {
          working.step += 1;
          working.scheduledDays = 0;
          working.due = reviewedAt.add(steps[working.step]);
        }
      case FsrsRating.easy:
        final int nextDays = _nextIntervalDays(working.stability!);
        working.state = FsrsState.review;
        working.step = 0;
        working.scheduledDays = nextDays;
        working.due = reviewedAt.add(Duration(days: nextDays));
    }
  }

  double _initialStability(FsrsRating rating) {
    return math.max(parameters[rating.value - 1], minimumStability);
  }

  double _initialDifficulty(FsrsRating rating, {required bool clamp}) {
    final double difficulty =
        parameters[4] - math.exp(parameters[5] * (rating.value - 1)) + 1;
    return clamp
        ? difficulty.clamp(minimumDifficulty, maximumDifficulty)
        : difficulty;
  }

  double _nextDifficulty({
    required double difficulty,
    required FsrsRating rating,
  }) {
    final double delta = -(parameters[6] * (rating.value - 3));
    final double damped = (10.0 - difficulty) * delta / 9.0;
    final double arg2 = difficulty + damped;
    final double arg1 = _initialDifficulty(FsrsRating.easy, clamp: false);
    final double reverted = parameters[7] * arg1 + (1 - parameters[7]) * arg2;
    return reverted.clamp(minimumDifficulty, maximumDifficulty);
  }

  double _nextStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required FsrsRating rating,
  }) {
    final double next = rating == FsrsRating.again
        ? _nextForgetStability(
            difficulty: difficulty,
            stability: stability,
            retrievability: retrievability,
          )
        : _nextRecallStability(
            difficulty: difficulty,
            stability: stability,
            retrievability: retrievability,
            rating: rating,
          );
    return math.max(next, minimumStability);
  }

  double _nextForgetStability({
    required double difficulty,
    required double stability,
    required double retrievability,
  }) {
    final double longTerm =
        parameters[11] *
        math.pow(difficulty, -parameters[12]) *
        (math.pow(stability + 1, parameters[13]) - 1) *
        math.exp((1 - retrievability) * parameters[14]);
    final double shortTerm =
        stability / math.exp(parameters[17] * parameters[18]);
    return math.min(longTerm, shortTerm);
  }

  double _nextRecallStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required FsrsRating rating,
  }) {
    final double hardPenalty = rating == FsrsRating.hard ? parameters[15] : 1.0;
    final double easyBonus = rating == FsrsRating.easy ? parameters[16] : 1.0;
    return stability *
        (1 +
            math.exp(parameters[8]) *
                (11 - difficulty) *
                math.pow(stability, -parameters[9]) *
                (math.exp((1 - retrievability) * parameters[10]) - 1) *
                hardPenalty *
                easyBonus);
  }

  double _shortTermStability({
    required double stability,
    required FsrsRating rating,
  }) {
    double increase =
        math.exp(parameters[17] * (rating.value - 3 + parameters[18])) *
        math.pow(stability, -parameters[19]);
    if (rating != FsrsRating.again) {
      increase = math.max(increase, 1.0);
    }
    return math.max(stability * increase, minimumStability);
  }

  double _retrievabilityFor({
    required double stability,
    required DateTime? lastReview,
    required DateTime reviewedAt,
  }) {
    if (lastReview == null) {
      return 0;
    }
    final int elapsedDays = math.max(
      0,
      reviewedAt.difference(lastReview.toUtc()).inDays,
    );
    return math
        .pow(1 + _factor * elapsedDays / stability, _decay)
        .toDouble()
        .clamp(0.0, 1.0);
  }

  int _nextIntervalDays(double stability) {
    final double next =
        (stability / _factor) *
        (math.pow(desiredRetention, 1 / _decay).toDouble() - 1);
    return next.round().clamp(1, maximumInterval);
  }

  int _fuzzDays(int days) {
    if (days < 3) {
      return days;
    }
    double delta = 1.0;
    final List<_FuzzRange> ranges = <_FuzzRange>[
      const _FuzzRange(start: 2.5, end: 7.0, factor: 0.15),
      const _FuzzRange(start: 7.0, end: 20.0, factor: 0.10),
      const _FuzzRange(start: 20.0, end: double.infinity, factor: 0.05),
    ];
    for (final _FuzzRange range in ranges) {
      delta +=
          range.factor *
          math.max(math.min(days.toDouble(), range.end) - range.start, 0.0);
    }
    int min = math.max(2, (days - delta).round());
    int max = math.min((days + delta).round(), maximumInterval);
    if (min > max) {
      min = max;
    }
    return (min + _random.nextDouble() * (max - min + 1)).round().clamp(
      min,
      max,
    );
  }
}

class _FuzzRange {
  const _FuzzRange({
    required this.start,
    required this.end,
    required this.factor,
  });

  final double start;
  final double end;
  final double factor;
}

/// Mutable implementation detail used only inside a single review call.
class _WorkingCard {
  _WorkingCard.from(FsrsCard card)
    : state = card.state,
      stability = card.stability,
      difficulty = card.difficulty,
      step = card.learningStep,
      scheduledDays = card.scheduledDays,
      due = card.due,
      reps = card.reps,
      lapses = card.lapses,
      lastReview = card.lastReview;

  FsrsState state;
  double? stability;
  double? difficulty;
  int step;
  int scheduledDays;
  DateTime due;
  int reps;
  int lapses;
  DateTime? lastReview;

  FsrsCard toCard() {
    return FsrsCard(
      state: state,
      due: due,
      stability: stability,
      difficulty: difficulty,
      elapsedDays: 0,
      scheduledDays: scheduledDays,
      learningStep: step,
      reps: reps,
      lapses: lapses,
      lastReview: lastReview,
    );
  }
}
