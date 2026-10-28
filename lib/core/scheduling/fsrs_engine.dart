import 'package:fsrs/fsrs.dart' as fsrs;

/// The three states FSRS knows about, mirrored so the rest of the app does not
/// have to import the scheduler package.
enum FsrsPhase { learning, review, relearning }

/// What FSRS remembers about one card between reviews.
///
/// This is a plain value object so the engine can stay free of Drift types:
/// the repository maps a `card_states` row onto it and maps the result back.
class FsrsMemory {
  const FsrsMemory({
    required this.phase,
    required this.step,
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.lastReview,
  });

  final FsrsPhase phase;

  /// Index into the learning or relearning steps. Ignored once the card has
  /// graduated to the review phase.
  final int? step;

  /// Days until recall decays to the target retention. Always > 0.
  final double stability;

  /// 1 (easy) to 10 (hard).
  final double difficulty;

  final DateTime due;

  final DateTime? lastReview;

  /// True when the row carries real FSRS numbers. A card scheduled by the old
  /// fixed intervals has both at 0, which the maths can never produce
  /// (stability has a floor of 0.001), so this is a safe marker.
  bool get isSchedulable => stability > 0 && difficulty > 0;

  /// Rebuilds the package's card object. Timestamps are forced to UTC because
  /// the scheduler rejects anything else.
  fsrs.Card toCard({required int cardId}) {
    return fsrs.Card(
      cardId: cardId,
      state: switch (phase) {
        FsrsPhase.learning => fsrs.State.learning,
        FsrsPhase.review => fsrs.State.review,
        FsrsPhase.relearning => fsrs.State.relearning,
      },
      step: phase == FsrsPhase.review ? null : step,
      stability: stability,
      difficulty: difficulty,
      due: due.toUtc(),
      lastReview: lastReview?.toUtc(),
    );
  }
}

/// The state a card should move to after one answer.
class FsrsOutcome {
  const FsrsOutcome({
    required this.phase,
    required this.step,
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.retrievability,
    required this.lapsed,
    required this.previous,
    required this.next,
  });

  final FsrsPhase phase;

  final int step;
  final double stability;
  final double difficulty;

  /// Next review instant, in UTC.
  final DateTime due;

  final int elapsedDays;
  final int scheduledDays;

  /// Probability the user still remembered the card at the moment it was
  /// answered, or null when the card had no memory state yet. A low value is
  /// what makes a long-overdue card schedule itself conservatively.
  final double? retrievability;

  /// True when a card that had graduated was forgotten.
  final bool lapsed;

  /// Snapshots stored on the review log, for later weight optimisation and
  /// for debugging a surprising interval.
  final Map<String, Object?> previous;
  final Map<String, Object?> next;
}

/// FSRS-6 scheduling, wrapped so the rest of the app never touches the
/// package's API directly.
///
/// Everything in and out of [review] is UTC. The engine is deliberately
/// stateless: one instance can serve every card, and a new one can be built
/// per deck when a deck overrides the desired retention.
class FsrsEngine {
  const FsrsEngine({
    this.desiredRetention = 0.9,
    this.maximumInterval = 36500,
    this.learningSteps = const <Duration>[
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    this.relearningSteps = const <Duration>[Duration(minutes: 10)],
    this.enableFuzzing = true,
  });

  /// The scheduler version written to `card_states.fsrs_version`.
  static const int version = 6;

  /// Share of cards the user should still remember when a card comes back.
  final double desiredRetention;

  /// Hard cap on how far ahead a card can be pushed, in days.
  final int maximumInterval;

  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;

  /// Spreads intervals by a few percent so a batch of cards learned on the
  /// same day does not come back as one avalanche.
  final bool enableFuzzing;

  fsrs.Scheduler _scheduler({bool? fuzz}) {
    return fsrs.Scheduler(
      desiredRetention: desiredRetention,
      maximumInterval: maximumInterval,
      learningSteps: learningSteps,
      relearningSteps: relearningSteps,
      enableFuzzing: fuzz ?? enableFuzzing,
    );
  }

  /// Applies one answer to [memory] and returns the next state.
  ///
  /// [memory] is null for a card that has never been scheduled, which is also
  /// what the caller passes for a card carrying the old fixed-interval state:
  /// FSRS re-seeds it as a new card, keeping only its review history.
  ///
  /// [now] may be in any timezone; it is converted to UTC here. A device clock
  /// that jumped backwards cannot produce a negative elapsed time because the
  /// previous review instant is clamped to [now] first.
  FsrsOutcome review({
    required String cardId,
    required FsrsMemory? memory,
    required int rating,
    required DateTime now,
    int? elapsedMs,
  }) {
    if (rating < 1 || rating > 4) {
      throw ArgumentError.value(rating, 'rating', 'must be between 1 and 4');
    }
    final DateTime nowUtc = now.toUtc();
    final fsrs.Scheduler scheduler = _scheduler();
    final int id = _stableId(cardId);

    // A row that claims to be in review without real numbers would make the
    // scheduler dereference null, so it is treated as a brand new card.
    final FsrsMemory? known =
        memory != null &&
            (memory.phase == FsrsPhase.learning || memory.isSchedulable)
        ? memory
        : null;

    fsrs.Card card = known == null
        ? fsrs.Card(cardId: id, due: nowUtc)
        : known.toCard(cardId: id);

    final DateTime? last = card.lastReview;
    if (last != null && last.isAfter(nowUtc)) {
      // The user changed the device clock. Treat the answer as if it arrived
      // exactly now rather than feeding the maths a negative gap.
      card = card.copyWith(lastReview: nowUtc);
    }

    final double? retrievability =
        card.lastReview == null || (card.stability ?? 0) <= 0
        ? null
        : scheduler
              .getCardRetrievability(card, currentDateTime: nowUtc)
              .clamp(0.0, 1.0)
              .toDouble();

    final Map<String, Object?> previous = _snapshot(card, retrievability);

    final ({fsrs.Card card, fsrs.ReviewLog reviewLog}) result = scheduler
        .reviewCard(
          card,
          fsrs.Rating.fromValue(rating),
          reviewDateTime: nowUtc,
          reviewDuration: elapsedMs,
        );
    final fsrs.Card next = result.card;

    final DateTime? reviewedAt = card.lastReview;
    final int elapsedDays = reviewedAt == null
        ? 0
        : _days(nowUtc.difference(reviewedAt));

    return FsrsOutcome(
      phase: switch (next.state) {
        fsrs.State.learning => FsrsPhase.learning,
        fsrs.State.review => FsrsPhase.review,
        fsrs.State.relearning => FsrsPhase.relearning,
      },
      step: next.step ?? 0,
      stability: next.stability ?? 0,
      difficulty: next.difficulty ?? 0,
      due: next.due,
      elapsedDays: elapsedDays,
      scheduledDays: _days(next.due.difference(nowUtc)),
      retrievability: retrievability,
      lapsed: known != null && known.phase == FsrsPhase.review && rating == 1,
      previous: previous,
      next: _snapshot(next, null),
    );
  }

  /// How long each button would push the card, for the labels under them.
  ///
  /// Fuzzing is off here on purpose: a preview that changes on every rebuild
  /// looks broken, and the fuzzed date is always within a few percent of this.
  Map<int, Duration> preview({FsrsMemory? memory, required DateTime now}) {
    final DateTime nowUtc = now.toUtc();
    final fsrs.Scheduler scheduler = _scheduler(fuzz: false);
    final FsrsMemory? known =
        memory != null &&
            (memory.phase == FsrsPhase.learning || memory.isSchedulable)
        ? memory
        : null;
    final Map<int, Duration> out = <int, Duration>{};
    for (int rating = 1; rating <= 4; rating++) {
      final fsrs.Card card = known == null
          ? fsrs.Card(cardId: 0, due: nowUtc)
          : known.toCard(cardId: 0);
      final fsrs.Card next = scheduler
          .reviewCard(
            card,
            fsrs.Rating.fromValue(rating),
            reviewDateTime: nowUtc,
          )
          .card;
      final Duration gap = next.due.difference(nowUtc);
      out[rating] = gap.isNegative ? Duration.zero : gap;
    }
    return out;
  }

  /// Probability that [memory] is still remembered at [now], 0 to 1.
  ///
  /// Returns null for a card FSRS has never seen.
  double? retrievabilityOf({
    required FsrsMemory? memory,
    required DateTime now,
  }) {
    if (memory == null || memory.lastReview == null || !memory.isSchedulable) {
      return null;
    }
    return _scheduler()
        .getCardRetrievability(
          memory.toCard(cardId: 0),
          currentDateTime: now.toUtc(),
        )
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static int _days(Duration value) {
    final int days = value.inDays;
    return days < 0 ? 0 : days;
  }

  static Map<String, Object?> _snapshot(
    fsrs.Card card,
    double? retrievability,
  ) {
    return <String, Object?>{
      'state': card.state.name,
      'step': card.step,
      'stability': card.stability,
      'difficulty': card.difficulty,
      'due': card.due.toUtc().toIso8601String(),
      'last_review': card.lastReview?.toUtc().toIso8601String(),
      'retrievability': retrievability,
    };
  }

  /// Stable 31-bit hash of a UUID, used as the package's integer card id.
  ///
  /// `String.hashCode` is not guaranteed to be stable across runs, and the id
  /// ends up in the review log, so a plain FNV-1a is safer.
  static int _stableId(String value) {
    int hash = 0x811c9dc5;
    for (final int unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
