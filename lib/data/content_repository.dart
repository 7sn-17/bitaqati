import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'local/app_database.dart';
import 'local/tables.dart';

/// Reads and writes decks, cards and reviews in the local Drift database.
///
/// Every write also queues a row in `sync_queue` so the future Supabase sync
/// knows what to push. Screens never touch the database directly.
class ContentRepository {
  ContentRepository(this._db, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// The app allows exactly two levels: a main deck and its sub-decks.
  ///
  /// This is stricter than the cloud `decks_depth_check` constraint, which is
  /// kept permissive so old rows stay readable; the invariant is enforced here
  /// so every screen inherits it.
  static const int maxDepth = kMaxDeckDepth;

  static const String _deckStatsSql = '''
SELECT d.*,
  (SELECT COUNT(*) FROM cards c
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL) AS own_cards,
  (SELECT COUNT(*) FROM cards c
    LEFT JOIN card_states s ON s.card_id = c.id
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL
      AND (s.card_id IS NULL OR s.status = 'newCard')) AS due_new,
  (SELECT COUNT(*) FROM cards c
    JOIN card_states s ON s.card_id = c.id
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL
      AND s.status IN ('learning', 'relearning')
      AND s.due <= CAST(strftime('%s', 'now') AS INTEGER)) AS due_learning,
  (SELECT COUNT(*) FROM cards c
    JOIN card_states s ON s.card_id = c.id
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL
      AND s.status = 'review'
      AND s.due <= CAST(strftime('%s', 'now') AS INTEGER)) AS due_review,
  (SELECT COUNT(*) FROM review_logs r
    JOIN cards c ON c.id = r.card_id
    WHERE c.deck_id = d.id) AS log_total,
  (SELECT COUNT(*) FROM review_logs r
    JOIN cards c ON c.id = r.card_id
    WHERE c.deck_id = d.id AND r.rating >= 2) AS log_ok
FROM decks d
WHERE d.deleted_at IS NULL
ORDER BY d.depth, d.position, d.created_at
''';

  // ---------------------------------------------------------------------------
  // Decks
  // ---------------------------------------------------------------------------

  /// Every live deck as a flat list, parents first. Counts include sub-decks.
  /// Use [buildDeckForest] to turn it into trees.
  Stream<List<DeckNode>> watchDecks() {
    final Selectable<QueryRow> query = _db.customSelect(
      _deckStatsSql,
      readsFrom: {_db.decks, _db.cards, _db.cardStates, _db.reviewLogs},
    );
    return query.watch().map(_buildNodes);
  }

  List<DeckNode> _buildNodes(List<QueryRow> rows) {
    final List<_DeckStats> all = <_DeckStats>[];
    for (final QueryRow row in rows) {
      all.add(
        _DeckStats(
          deck: _db.decks.map(row.data),
          ownCards: row.read<int>('own_cards'),
          dueNew: row.read<int>('due_new'),
          dueLearning: row.read<int>('due_learning'),
          dueReview: row.read<int>('due_review'),
          reviews: row.read<int>('log_total'),
          correct: row.read<int>('log_ok'),
        ),
      );
    }

    final Map<String, List<_DeckStats>> childrenOf =
        <String, List<_DeckStats>>{};
    for (final _DeckStats item in all) {
      final String? parent = item.deck.parentId;
      if (parent != null) {
        childrenOf.putIfAbsent(parent, () => <_DeckStats>[]).add(item);
      }
    }

    final Map<String, _Totals> memo = <String, _Totals>{};
    _Totals totalsOf(_DeckStats item) {
      final _Totals? cached = memo[item.deck.id];
      if (cached != null) {
        return cached;
      }
      int cards = item.ownCards;
      int dueNew = item.dueNew;
      int dueLearning = item.dueLearning;
      int dueReview = item.dueReview;
      int reviews = item.reviews;
      int correct = item.correct;
      final List<_DeckStats> kids =
          childrenOf[item.deck.id] ?? const <_DeckStats>[];
      for (final _DeckStats child in kids) {
        final _Totals sub = totalsOf(child);
        cards += sub.cards;
        dueNew += sub.dueNew;
        dueLearning += sub.dueLearning;
        dueReview += sub.dueReview;
        reviews += sub.reviews;
        correct += sub.correct;
      }
      final _Totals result = _Totals(
        cards: cards,
        dueNew: dueNew,
        dueLearning: dueLearning,
        dueReview: dueReview,
        reviews: reviews,
        correct: correct,
      );
      memo[item.deck.id] = result;
      return result;
    }

    final List<DeckNode> nodes = <DeckNode>[];
    for (final _DeckStats item in all) {
      final DeckRow deck = item.deck;
      final _Totals totals = totalsOf(item);
      nodes.add(
        DeckNode(
          id: deck.id,
          parentId: deck.parentId,
          rootId: deck.rootId,
          depth: deck.depth,
          position: deck.position,
          title: deck.title,
          description: deck.description,
          color: colorFromHex(deck.colorHex),
          iconKey: deck.icon,
          tags: deck.tags,
          isPublic: deck.privacy == DeckPrivacy.public,
          ownCardCount: item.ownCards,
          cardCount: totals.cards,
          dueNew: totals.dueNew,
          dueLearning: totals.dueLearning,
          dueReview: totals.dueReview,
          reviewCount: totals.reviews,
          correctCount: totals.correct,
          childCount: childrenOf[deck.id]?.length ?? 0,
        ),
      );
    }
    return nodes;
  }

  /// Creates a root deck, or a sub-deck when [parentId] is given.
  ///
  /// `root_id`, `path` and `depth` are computed here the same way the cloud
  /// trigger does, so rows can be pushed to Supabase unchanged.
  Future<String> createDeck({
    required String title,
    String? parentId,
    String description = '',
    String colorHex = kDefaultDeckColorHex,
    String icon = 'layers',
    List<String> tags = const <String>[],
  }) {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 160) {
      throw ArgumentError.value(title, 'title', 'must be 1 to 160 characters');
    }
    return _db.transaction(() async {
      final String id = _uuid.v4();
      String rootId = id;
      List<String> path = const <String>[];
      int depth = 0;

      if (parentId != null) {
        final String parentKey = parentId;
        final DeckRow? parent =
            await (_db.select(_db.decks)..where(
                  (d) => d.id.equals(parentKey) & d.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (parent == null) {
          throw StateError('Parent deck $parentKey does not exist');
        }
        if (parent.depth >= maxDepth) {
          throw StateError(
            'A sub-deck cannot contain another sub-deck '
            '(maximum depth is $maxDepth)',
          );
        }
        rootId = parent.rootId ?? parent.id;
        path = <String>[...parent.path, parent.id];
        depth = parent.depth + 1;
      }

      final QueryRow next = await _db
          .customSelect(
            'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM decks '
            'WHERE parent_id IS ? AND deleted_at IS NULL',
            variables: [Variable<String>(parentId)],
            readsFrom: {_db.decks},
          )
          .getSingle();

      await _db
          .into(_db.decks)
          .insert(
            DecksCompanion.insert(
              id: id,
              title: cleanTitle,
              parentId: Value(parentId),
              rootId: Value(rootId),
              path: Value(path),
              depth: Value(depth),
              position: Value(next.read<int>('next')),
              description: Value(description.trim()),
              colorHex: Value(colorHex),
              icon: Value(icon),
              tags: Value(_cleanTags(tags)),
            ),
          );
      await _enqueue('decks', id, SyncOperation.upsert);
      return id;
    });
  }

  // ---------------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------------

  /// Cards that sit directly in [deckId], oldest first.
  Stream<List<ReviewCard>> watchCards(String deckId) {
    final query = _db
        .select(_db.cards)
        .join([
          leftOuterJoin(
            _db.cardStates,
            _db.cardStates.cardId.equalsExp(_db.cards.id),
          ),
        ]);
    query
      ..where(_db.cards.deckId.equals(deckId) & _db.cards.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.asc(_db.cards.position),
        OrderingTerm.asc(_db.cards.createdAt),
      ]);
    return query.watch().map(_toCards);
  }

  Future<String> addCard({
    required String deckId,
    required String front,
    required String back,
    String hint = '',
    String note = '',
    List<String> tags = const <String>[],
  }) {
    final String cleanFront = front.trim();
    final String cleanBack = back.trim();
    if (cleanFront.isEmpty || cleanBack.isEmpty) {
      throw ArgumentError('A card needs both a front and a back');
    }
    return _db.transaction(() async {
      final DeckRow? deck =
          await (_db.select(_db.decks)..where(
                (d) => d.id.equals(deckId) & d.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (deck == null) {
        throw StateError('Deck $deckId does not exist');
      }
      if (deck.depth < kSubDeckDepth) {
        throw StateError(
          'Cards belong to sub-decks; deck $deckId is a main deck',
        );
      }
      final String id = _uuid.v4();
      final QueryRow next = await _db
          .customSelect(
            'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM cards '
            'WHERE deck_id = ? AND deleted_at IS NULL',
            variables: [Variable<String>(deckId)],
            readsFrom: {_db.cards},
          )
          .getSingle();
      await _db
          .into(_db.cards)
          .insert(
            CardsCompanion.insert(
              id: id,
              deckId: deckId,
              front: Value(cleanFront),
              back: Value(cleanBack),
              hint: Value(hint.trim()),
              notes: Value(note.trim()),
              tags: Value(_cleanTags(tags)),
              position: Value(next.read<int>('next')),
            ),
          );
      await _enqueue('cards', id, SyncOperation.upsert);
      return id;
    });
  }

  /// Cards to study now in [deckId] and every deck nested under it:
  /// learning first, then reviews, then new cards.
  Future<List<ReviewCard>> studyQueue(String deckId, {int limit = 200}) async {
    final List<DeckRow> decks = await (_db.select(
      _db.decks,
    )..where((d) => d.deletedAt.isNull())).get();
    final List<String> ids = <String>[];
    for (final DeckRow deck in decks) {
      if (deck.id == deckId || deck.path.contains(deckId)) {
        ids.add(deck.id);
      }
    }
    if (ids.isEmpty) {
      return const <ReviewCard>[];
    }

    final query = _db
        .select(_db.cards)
        .join([
          leftOuterJoin(
            _db.cardStates,
            _db.cardStates.cardId.equalsExp(_db.cards.id),
          ),
        ]);
    query
      ..where(_db.cards.deckId.isIn(ids) & _db.cards.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.asc(_db.cards.position),
        OrderingTerm.asc(_db.cards.createdAt),
      ]);
    final List<TypedResult> rows = await query.get();

    final DateTime now = _clock();
    final List<ReviewCard> learning = <ReviewCard>[];
    final List<ReviewCard> review = <ReviewCard>[];
    final List<ReviewCard> fresh = <ReviewCard>[];
    for (final TypedResult row in rows) {
      final CardRow card = row.readTable(_db.cards);
      final CardStateRow? state = row.readTableOrNull(_db.cardStates);
      final ReviewCard item = _toCard(card, state);
      switch (item.phase) {
        case CardPhase.newCard:
          fresh.add(item);
        case CardPhase.learning:
          if (state != null && !state.due.isAfter(now)) {
            learning.add(item);
          }
        case CardPhase.review:
          if (state != null && !state.due.isAfter(now)) {
            review.add(item);
          }
        case CardPhase.paused:
          break;
      }
    }
    final List<ReviewCard> queue = <ReviewCard>[
      ...learning,
      ...review,
      ...fresh,
    ];
    return queue.take(limit).toList(growable: false);
  }

  /// Cards whose front, back or tags contain [query]. With an empty query it
  /// returns the three newest cards, used as suggestions.
  Future<List<ReviewCard>> searchCards(String query, {int limit = 20}) async {
    final String needle = query.trim();
    final matches = _db
        .select(_db.cards)
        .join([
          leftOuterJoin(
            _db.cardStates,
            _db.cardStates.cardId.equalsExp(_db.cards.id),
          ),
        ]);
    final Expression<bool> alive = _db.cards.deletedAt.isNull();
    if (needle.isEmpty) {
      matches.where(alive);
    } else {
      final String pattern = '%$needle%';
      matches.where(
        alive &
            (_db.cards.front.like(pattern) |
                _db.cards.back.like(pattern) |
                _db.cards.tags.like(pattern)),
      );
    }
    matches
      ..orderBy([OrderingTerm.desc(_db.cards.createdAt)])
      ..limit(needle.isEmpty ? 3 : limit);
    final List<TypedResult> rows = await matches.get();
    return _toCards(rows);
  }

  List<ReviewCard> _toCards(List<TypedResult> rows) {
    final List<ReviewCard> cards = <ReviewCard>[];
    for (final TypedResult row in rows) {
      cards.add(
        _toCard(
          row.readTable(_db.cards),
          row.readTableOrNull(_db.cardStates),
        ),
      );
    }
    return cards;
  }

  ReviewCard _toCard(CardRow card, CardStateRow? state) {
    return ReviewCard(
      id: card.id,
      deckId: card.deckId,
      front: card.front,
      back: card.back,
      hint: card.hint.isEmpty ? null : card.hint,
      note: card.notes.isEmpty ? null : card.notes,
      tags: card.tags,
      phase: _phaseOf(state),
    );
  }

  CardPhase _phaseOf(CardStateRow? state) {
    if (state == null) {
      return CardPhase.newCard;
    }
    switch (state.status) {
      case CardStatus.newCard:
        return CardPhase.newCard;
      case CardStatus.learning:
      case CardStatus.relearning:
        return CardPhase.learning;
      case CardStatus.review:
        return CardPhase.review;
      case CardStatus.suspended:
      case CardStatus.buried:
        return CardPhase.paused;
    }
  }

  // ---------------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------------

  /// Saves one answer: an append-only log row plus the card's new state.
  ///
  /// [rating] is 1 again, 2 hard, 3 good, 4 easy. Until the FSRS engine
  /// lands, the next due date uses the fixed intervals the rating buttons
  /// already show (1 minute, 2 days, 5 days, 11 days).
  Future<void> recordReview({
    required String cardId,
    required int rating,
    int? elapsedMs,
  }) {
    if (rating < 1 || rating > 4) {
      throw ArgumentError.value(rating, 'rating', 'must be between 1 and 4');
    }
    return _db.transaction(() async {
      final DateTime now = _clock();
      final CardStateRow? previous =
          await (_db.select(_db.cardStates)..where(
                (s) => s.cardId.equals(cardId),
              ))
              .getSingleOrNull();

      final Duration interval = _intervalFor(rating);
      final CardStatus next = rating == 1
          ? CardStatus.learning
          : CardStatus.review;
      final bool lapsed = rating == 1 && previous?.status == CardStatus.review;
      final DateTime? last = previous?.lastReview;
      final int elapsedDays = last == null ? 0 : now.difference(last).inDays;

      await _db
          .into(_db.cardStates)
          .insertOnConflictUpdate(
            CardStatesCompanion(
              cardId: Value(cardId),
              status: Value(next),
              due: Value(now.add(interval)),
              elapsedDays: Value(elapsedDays),
              scheduledDays: Value(interval.inDays),
              reps: Value((previous?.reps ?? 0) + 1),
              lapses: Value((previous?.lapses ?? 0) + (lapsed ? 1 : 0)),
              lastReview: Value(now),
              updatedAt: Value(now),
            ),
          );

      final String logId = _uuid.v4();
      await _db
          .into(_db.reviewLogs)
          .insert(
            ReviewLogsCompanion.insert(
              id: logId,
              cardId: cardId,
              rating: rating,
              reviewedAt: Value(now),
              elapsedMs: Value(elapsedMs),
              scheduledDays: Value(interval.inDays),
            ),
          );
      await _enqueue('card_states', cardId, SyncOperation.upsert);
      await _enqueue('review_logs', logId, SyncOperation.upsert);
    });
  }

  Duration _intervalFor(int rating) {
    switch (rating) {
      case 1:
        return const Duration(minutes: 1);
      case 2:
        return const Duration(days: 2);
      case 3:
        return const Duration(days: 5);
      default:
        return const Duration(days: 11);
    }
  }

  /// Consecutive days, ending today or yesterday, with at least one answer.
  Stream<int> watchStreak() {
    final Selectable<QueryRow> query = _db.customSelect(
      "SELECT DISTINCT date(reviewed_at, 'unixepoch', 'localtime') AS day "
      'FROM review_logs ORDER BY day DESC LIMIT 400',
      readsFrom: {_db.reviewLogs},
    );
    return query.watch().map((List<QueryRow> rows) {
      final Set<String> days = <String>{
        for (final QueryRow row in rows) row.read<String>('day'),
      };
      final DateTime now = _clock();
      DateTime cursor = DateTime(now.year, now.month, now.day);
      if (!days.contains(_dayKey(cursor))) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      int streak = 0;
      while (days.contains(_dayKey(cursor))) {
        streak++;
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      }
      return streak;
    });
  }

  String _dayKey(DateTime day) {
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _enqueue(
    String entity,
    String entityId,
    SyncOperation operation,
  ) async {
    await _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entity: entity,
            entityId: entityId,
            operation: operation,
          ),
        );
  }

  List<String> _cleanTags(List<String> tags) {
    final List<String> out = <String>[];
    for (final String raw in tags) {
      final String tag = raw.trim();
      if (tag.isNotEmpty && !out.contains(tag)) {
        out.add(tag);
      }
    }
    return out;
  }
}

class _DeckStats {
  const _DeckStats({
    required this.deck,
    required this.ownCards,
    required this.dueNew,
    required this.dueLearning,
    required this.dueReview,
    required this.reviews,
    required this.correct,
  });

  final DeckRow deck;
  final int ownCards;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviews;
  final int correct;
}

class _Totals {
  const _Totals({
    required this.cards,
    required this.dueNew,
    required this.dueLearning,
    required this.dueReview,
    required this.reviews,
    required this.correct,
  });

  final int cards;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviews;
  final int correct;
}
