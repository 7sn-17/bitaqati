import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/enums.dart';
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
  /// This matches the cloud `decks_depth_check` and local Drift constraints;
  /// it is also enforced here so every screen inherits the invariant before a
  /// write ever reaches SQLite.
  static const int maxDepth = kMaxDeckDepth;

  static const String _deckStatsSql = '''
SELECT d.*,
  (SELECT COUNT(*) FROM cards c
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL) AS own_cards,
  (SELECT COUNT(*) FROM cards c
    JOIN card_states s ON s.card_id = c.id
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL
      AND s.status = 'review') AS mastered,
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
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL) AS log_total,
  (SELECT COUNT(*) FROM review_logs r
    JOIN cards c ON c.id = r.card_id
    WHERE c.deck_id = d.id AND c.deleted_at IS NULL
      AND r.rating >= 2) AS log_ok
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
          mastered: row.read<int>('mastered'),
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
      int mastered = item.mastered;
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
        mastered += sub.mastered;
        dueNew += sub.dueNew;
        dueLearning += sub.dueLearning;
        dueReview += sub.dueReview;
        reviews += sub.reviews;
        correct += sub.correct;
      }
      final _Totals result = _Totals(
        cards: cards,
        mastered: mastered,
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
          privacy: deck.privacy,
          isPublic: deck.privacy == DeckPrivacy.public,
          publishedAt: deck.publishedAt,
          sourceDeckId: deck.sourceDeckId,
          ownCardCount: item.ownCards,
          cardCount: totals.cards,
          masteredCount: totals.mastered,
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
            await (_db.select(_db.decks)
                  ..where((d) => d.id.equals(parentKey) & d.deletedAt.isNull()))
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

  /// Updates the editable identity of a deck. Cards and scheduling state are
  /// untouched, so renaming a deck never resets review history.
  Future<void> updateDeck({
    required String deckId,
    required String title,
    required String colorHex,
    required String icon,
    String? description,
    List<String>? tags,
  }) {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 160) {
      throw ArgumentError.value(title, 'title', 'must be 1 to 160 characters');
    }
    return _db.transaction(() async {
      final DeckRow? existing =
          await (_db.select(_db.decks)
                ..where((d) => d.id.equals(deckId) & d.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing == null) {
        throw StateError('Deck $deckId does not exist');
      }
      await (_db.update(_db.decks)..where((d) => d.id.equals(deckId))).write(
        DecksCompanion(
          title: Value<String>(cleanTitle),
          colorHex: Value<String>(colorHex),
          icon: Value<String>(icon),
          description: description == null
              ? const Value<String>.absent()
              : Value<String>(description.trim()),
          tags: tags == null
              ? const Value<List<String>>.absent()
              : Value<List<String>>(_cleanTags(tags)),
          updatedAt: Value<DateTime>(_clock()),
        ),
      );
      await _enqueue('decks', deckId, SyncOperation.upsert);
    });
  }

  /// Soft-deletes a deck, its sub-decks, and every card inside them.
  Future<void> deleteDeck(String deckId) {
    return _db.transaction(() async {
      final DateTime now = _clock();
      final List<DeckRow> live = await (_db.select(
        _db.decks,
      )..where((d) => d.deletedAt.isNull())).get();
      final List<String> ids = <String>[];
      for (final DeckRow deck in live) {
        if (deck.id == deckId || deck.path.contains(deckId)) {
          ids.add(deck.id);
        }
      }
      if (!ids.contains(deckId)) {
        throw StateError('Deck $deckId does not exist');
      }
      final List<CardRow> cards = await (_db.select(_db.cards)
            ..where((c) => c.deckId.isIn(ids) & c.deletedAt.isNull()))
          .get();
      await (_db.update(_db.cards)
            ..where((c) => c.deckId.isIn(ids) & c.deletedAt.isNull()))
          .write(
            CardsCompanion(
              deletedAt: Value<DateTime>(now),
              updatedAt: Value<DateTime>(now),
            ),
          );
      await (_db.update(_db.decks)..where((d) => d.id.isIn(ids))).write(
        DecksCompanion(
          deletedAt: Value<DateTime>(now),
          updatedAt: Value<DateTime>(now),
        ),
      );
      for (final CardRow card in cards) {
        await _enqueue('cards', card.id, SyncOperation.delete);
      }
      for (final String id in ids) {
        await _enqueue('decks', id, SyncOperation.delete);
      }
    });
  }

  /// The stored privacy of one deck, or null when it no longer exists.
  Future<DeckPrivacy?> deckPrivacy(String deckId) async {
    final DeckRow? row = await (_db.select(_db.decks)
          ..where((d) => d.id.equals(deckId) & d.deletedAt.isNull()))
        .getSingleOrNull();
    return row?.privacy;
  }

  /// Stores the sharing state locally after a successful cloud publish.
  Future<void> setDeckPrivacy(
    String deckId,
    DeckPrivacy privacy, {
    bool includeChildren = true,
  }) {
    return _db.transaction(() async {
      final DateTime now = _clock();
      final List<DeckRow> live = await (_db.select(
        _db.decks,
      )..where((d) => d.deletedAt.isNull())).get();
      final List<String> ids = <String>[];
      for (final DeckRow deck in live) {
        if (deck.id == deckId ||
            (includeChildren && deck.path.contains(deckId))) {
          ids.add(deck.id);
        }
      }
      if (ids.isEmpty) {
        throw StateError('Deck $deckId does not exist');
      }
      await (_db.update(_db.decks)..where((d) => d.id.isIn(ids))).write(
        DecksCompanion(
          privacy: Value<DeckPrivacy>(privacy),
          publishedAt: Value<DateTime?>(
            privacy == DeckPrivacy.private ? null : now,
          ),
          updatedAt: Value<DateTime>(now),
        ),
      );
      for (final String id in ids) {
        await _enqueue('decks', id, SyncOperation.upsert);
      }
    });
  }

  /// Reads a deck (and, for a main deck, its sub-decks) plus every card.
  Future<DeckBundle> exportDeckBundle(String deckId) async {
    final DeckRow? root =
        await (_db.select(_db.decks)
              ..where((d) => d.id.equals(deckId) & d.deletedAt.isNull()))
            .getSingleOrNull();
    if (root == null) {
      throw StateError('Deck $deckId does not exist');
    }
    final List<DeckRow> children = root.depth == kMainDeckDepth
        ? await (_db.select(_db.decks)
              ..where(
                (d) => d.parentId.equals(deckId) & d.deletedAt.isNull(),
              )
              ..orderBy([(d) => OrderingTerm.asc(d.position)]))
            .get()
        : const <DeckRow>[];
    final List<DeckRow> rows = <DeckRow>[root, ...children];
    final List<String> ids = rows.map((DeckRow deck) => deck.id).toList();
    final List<CardRow> cards = await (_db.select(_db.cards)
          ..where((c) => c.deckId.isIn(ids) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.position)]))
        .get();

    return DeckBundle(
      root: _deckNodeFromRow(root, cardCount: cards.length),
      nodes: <DeckBundleNode>[
        for (final DeckRow row in rows)
          DeckBundleNode(
            id: row.id,
            parentId: row.parentId,
            depth: row.depth,
            position: row.position,
            title: row.title,
            description: row.description,
            colorHex: row.colorHex,
            icon: row.icon,
            tags: row.tags,
            settings: row.settings,
            coverUrl: row.coverUrl,
            sourceDeckId: row.sourceDeckId,
            sourceVersion: row.sourceVersion,
            publishedAt: row.publishedAt,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
      ],
      cards: <DeckBundleCard>[
        for (final CardRow card in cards)
          DeckBundleCard(
            id: card.id,
            deckId: card.deckId,
            type: card.type.name,
            front: card.front,
            back: card.back,
            notes: card.notes,
            hint: card.hint,
            tags: card.tags,
            media: card.media,
            occlusion: card.occlusion,
            source: card.source,
            aiGenerated: card.aiGenerated,
            position: card.position,
            createdAt: card.createdAt,
            updatedAt: card.updatedAt,
          ),
      ],
    );
  }

  /// Copies a library or shared deck into the local database.
  ///
  /// The source root becomes a main deck. Cards that live directly on the
  /// source root are placed in a generated sub-deck, because the local
  /// hierarchy never allows cards on a main deck.
  Future<String> importDeckBundle(DeckBundle bundle) {
    return _db.transaction(() async {
      final DateTime now = _clock();
      final DeckBundleNode rootNode = bundle.nodes.firstWhere(
        (DeckBundleNode node) => node.id == bundle.root.id,
        orElse: () => DeckBundleNode(
          id: bundle.root.id,
          parentId: null,
          depth: 0,
          position: 0,
          title: bundle.root.title,
          description: bundle.root.description,
          colorHex: colorToHex(bundle.root.color),
          icon: bundle.root.iconKey,
          tags: bundle.root.tags,
        ),
      );
      final List<DeckBundleNode> childNodes = bundle.nodes
          .where(
            (DeckBundleNode node) =>
                node.id != rootNode.id &&
                (node.parentId == rootNode.id || node.depth == 1),
          )
          .toList(growable: false);

      final String rootId = _uuid.v4();
      final Map<String, String> deckIds = <String, String>{
        rootNode.id: rootId,
      };

      await _db
          .into(_db.decks)
          .insert(
            DecksCompanion.insert(
              id: rootId,
              title: rootNode.title,
              rootId: Value<String>(rootId),
              depth: const Value<int>(kMainDeckDepth),
              position: const Value<int>(0),
              description: Value<String>(rootNode.description),
              colorHex: Value<String?>(
                rootNode.colorHex ?? colorToHex(bundle.root.color),
              ),
              icon: Value<String>(rootNode.icon),
              tags: Value<List<String>>(rootNode.tags),
              settings: Value<Map<String, Object?>>(rootNode.settings),
              sourceDeckId: Value<String?>(bundle.root.id),
              sourceVersion: Value<int>(rootNode.sourceVersion),
              forkedAt: Value<DateTime>(now),
            ),
          );

      for (int index = 0; index < childNodes.length; index++) {
        final DeckBundleNode child = childNodes[index];
        final String childId = _uuid.v4();
        deckIds[child.id] = childId;
        await _db
            .into(_db.decks)
            .insert(
              DecksCompanion.insert(
                id: childId,
                title: child.title,
                parentId: Value<String?>(rootId),
                rootId: Value<String>(rootId),
                path: Value<List<String>>(<String>[rootId]),
                depth: const Value<int>(kSubDeckDepth),
                position: Value<int>(index),
                description: Value<String>(child.description),
                colorHex: Value<String?>(
                  child.colorHex ?? colorToHex(bundle.root.color),
                ),
                icon: Value<String>(child.icon),
                tags: Value<List<String>>(child.tags),
                settings: Value<Map<String, Object?>>(child.settings),
                sourceDeckId: Value<String?>(child.id),
                sourceVersion: Value<int>(child.sourceVersion),
                forkedAt: Value<DateTime>(now),
              ),
            );
      }

      final Map<String, String> cardDeckIds = <String, String>{
        ...deckIds,
      };
      final bool rootHasCards = bundle.cards.any(
        (DeckBundleCard card) => card.deckId == rootNode.id,
      );
      if (rootHasCards) {
        final String containerId = _uuid.v4();
        cardDeckIds[rootNode.id] = containerId;
        await _db
            .into(_db.decks)
            .insert(
              DecksCompanion.insert(
                id: containerId,
                title: 'البطاقات',
                parentId: Value<String?>(rootId),
                rootId: Value<String>(rootId),
                path: Value<List<String>>(<String>[rootId]),
                depth: const Value<int>(kSubDeckDepth),
                position: Value<int>(childNodes.length),
                description: const Value<String>(''),
                colorHex: Value<String?>(
                  rootNode.colorHex ?? colorToHex(bundle.root.color),
                ),
                icon: Value<String>(rootNode.icon),
                sourceDeckId: const Value<String?>(null),
                sourceVersion: Value<int>(rootNode.sourceVersion),
                forkedAt: Value<DateTime>(now),
              ),
            );
      }

      for (final DeckBundleCard card in bundle.cards) {
        final String? localDeckId =
            cardDeckIds[card.deckId] ?? deckIds[card.deckId];
        if (localDeckId == null) {
          continue;
        }
        final CardType type = CardType.values.firstWhere(
          (CardType value) => value.name == card.type,
          orElse: () => CardType.basic,
        );
        final String cardId = _uuid.v4();
        await _db
            .into(_db.cards)
            .insert(
              CardsCompanion.insert(
                id: cardId,
                deckId: localDeckId,
                type: Value<CardType>(type),
                front: Value<String>(card.front),
                back: Value<String>(card.back),
                notes: Value<String>(card.notes),
                hint: Value<String>(card.hint),
                tags: Value<List<String>>(card.tags),
                media: Value<List<Object?>>(card.media),
                occlusion: Value<Map<String, Object?>?>(card.occlusion),
                source: Value<String?>(card.source),
                aiGenerated: Value<bool>(card.aiGenerated),
                position: Value<int>(card.position),
                createdAt: Value<DateTime>(now),
                updatedAt: Value<DateTime>(now),
              ),
            );
        await _enqueue('cards', cardId, SyncOperation.upsert);
      }

      await _enqueue('decks', rootId, SyncOperation.upsert);
      for (final String id in deckIds.values) {
        if (id != rootId) {
          await _enqueue('decks', id, SyncOperation.upsert);
        }
      }
      if (rootHasCards) {
        final String? container = cardDeckIds[rootNode.id];
        if (container != null) {
          await _enqueue('decks', container, SyncOperation.upsert);
        }
      }
      return rootId;
    });
  }

  // ---------------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------------

  /// Cards that sit directly in [deckId], oldest first.
  Stream<List<ReviewCard>> watchCards(String deckId) {
    final query = _db.select(_db.cards).join([
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
    String type = 'basic',
    Map<String, Object?>? occlusion,
  }) {
    final String cleanFront = front.trim();
    final String cleanBack = back.trim();
    if (cleanFront.isEmpty || cleanBack.isEmpty) {
      throw ArgumentError('A card needs both a front and a back');
    }
    return _db.transaction(() async {
      final DeckRow? deck =
          await (_db.select(_db.decks)
                ..where((d) => d.id.equals(deckId) & d.deletedAt.isNull()))
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
              type: Value<CardType>(_cardTypeFromName(type)),
              front: Value(cleanFront),
              back: Value(cleanBack),
              hint: Value(hint.trim()),
              notes: Value(note.trim()),
              tags: Value(_cleanTags(tags)),
              occlusion: Value<Map<String, Object?>?>(occlusion),
              position: Value(next.read<int>('next')),
            ),
          );
      await _enqueue('cards', id, SyncOperation.upsert);
      return id;
    });
  }

  /// Updates the editable fields of an existing card.
  ///
  /// The deck and the review state are intentionally left untouched, so
  /// editing a card mid-session never resets its scheduling.
  Future<void> updateCard({
    required String cardId,
    required String front,
    required String back,
    String hint = '',
    String note = '',
    List<String> tags = const <String>[],
    String type = 'basic',
    Map<String, Object?>? occlusion,
  }) {
    final String cleanFront = front.trim();
    final String cleanBack = back.trim();
    if (cleanFront.isEmpty || cleanBack.isEmpty) {
      throw ArgumentError('A card needs both a front and a back');
    }
    return _db.transaction(() async {
      final CardRow? existing =
          await (_db.select(_db.cards)
                ..where((c) => c.id.equals(cardId) & c.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing == null) {
        throw StateError('Card $cardId does not exist');
      }
      await (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(
          type: Value<CardType>(_cardTypeFromName(type)),
          front: Value(cleanFront),
          back: Value(cleanBack),
          hint: Value(hint.trim()),
          notes: Value(note.trim()),
          tags: Value(_cleanTags(tags)),
          occlusion: Value<Map<String, Object?>?>(occlusion),
          updatedAt: Value(_clock()),
        ),
      );
      await _enqueue('cards', cardId, SyncOperation.upsert);
    });
  }

  /// Pins or unpins a card locally.
  Future<void> setCardFavorite(String cardId, bool favorite) {
    return _db.transaction(() async {
      await (_db.update(_db.cards)
            ..where((c) => c.id.equals(cardId) & c.deletedAt.isNull()))
          .write(
            CardsCompanion(
              favorite: Value<bool>(favorite),
              updatedAt: Value<DateTime>(_clock()),
            ),
          );
      await _enqueue('cards', cardId, SyncOperation.upsert);
    });
  }

  /// Moves several cards into another sub-deck in one transaction.
  Future<void> moveCards({
    required List<String> cardIds,
    required String deckId,
  }) {
    return _db.transaction(() async {
      final DeckRow? deck =
          await (_db.select(_db.decks)
                ..where((d) => d.id.equals(deckId) & d.deletedAt.isNull()))
              .getSingleOrNull();
      if (deck == null || deck.depth < kSubDeckDepth) {
        throw StateError('Cards can only move into a sub-deck');
      }
      await (_db.update(_db.cards)..where(
            (c) => c.id.isIn(cardIds) & c.deletedAt.isNull(),
          ))
          .write(
            CardsCompanion(
              deckId: Value<String>(deckId),
              updatedAt: Value<DateTime>(_clock()),
            ),
          );
      for (final String id in cardIds) {
        await _enqueue('cards', id, SyncOperation.upsert);
      }
    });
  }

  /// Adds [tags] to each card without replacing tags it already has.
  Future<void> addTagsToCards({
    required List<String> cardIds,
    required List<String> tags,
  }) {
    final List<String> additions = _cleanTags(tags);
    if (additions.isEmpty) {
      return Future<void>.value();
    }
    return _db.transaction(() async {
      final List<CardRow> cards = await (_db.select(_db.cards)
            ..where((c) => c.id.isIn(cardIds) & c.deletedAt.isNull()))
          .get();
      for (final CardRow card in cards) {
        final List<String> merged = <String>{
          ...card.tags,
          ...additions,
        }.toList(growable: false);
        await (_db.update(_db.cards)..where((c) => c.id.equals(card.id))).write(
          CardsCompanion(
            tags: Value<List<String>>(merged),
            updatedAt: Value<DateTime>(_clock()),
          ),
        );
        await _enqueue('cards', card.id, SyncOperation.upsert);
      }
    });
  }

  /// Suspends or restores cards. Restored cards keep their review history and
  /// become due immediately so they can rejoin the queue.
  Future<void> setCardsSuspended({
    required List<String> cardIds,
    required bool suspended,
  }) {
    return _db.transaction(() async {
      final DateTime now = _clock();
      for (final String cardId in cardIds) {
        final CardStateRow? previous =
            await (_db.select(_db.cardStates)
                  ..where((s) => s.cardId.equals(cardId)))
                .getSingleOrNull();
        if (suspended) {
          await _db
              .into(_db.cardStates)
              .insertOnConflictUpdate(
                CardStatesCompanion(
                  cardId: Value<String>(cardId),
                  status: Value<CardStatus>(CardStatus.suspended),
                  due: Value<DateTime>(previous?.due ?? now),
                  elapsedDays: Value<int>(previous?.elapsedDays ?? 0),
                  scheduledDays: Value<int>(previous?.scheduledDays ?? 0),
                  reps: Value<int>(previous?.reps ?? 0),
                  lapses: Value<int>(previous?.lapses ?? 0),
                  lastReview: Value<DateTime?>(previous?.lastReview),
                  updatedAt: Value<DateTime>(now),
                ),
              );
        } else if (previous != null &&
            (previous.status == CardStatus.suspended ||
                previous.status == CardStatus.buried)) {
          await _db
              .into(_db.cardStates)
              .insertOnConflictUpdate(
                CardStatesCompanion(
                  cardId: Value<String>(cardId),
                  status: Value<CardStatus>(
                    previous.reps > 0 ? CardStatus.review : CardStatus.newCard,
                  ),
                  due: Value<DateTime>(now),
                  elapsedDays: Value<int>(previous.elapsedDays),
                  scheduledDays: Value<int>(previous.scheduledDays),
                  reps: Value<int>(previous.reps),
                  lapses: Value<int>(previous.lapses),
                  lastReview: Value<DateTime?>(previous.lastReview),
                  updatedAt: Value<DateTime>(now),
                ),
              );
        } else {
          continue;
        }
        await _enqueue('card_states', cardId, SyncOperation.upsert);
      }
    });
  }

  /// Soft-deletes cards. Review history remains for statistics and undo.
  Future<void> deleteCards(List<String> cardIds) {
    return _db.transaction(() async {
      final DateTime now = _clock();
      final List<CardRow> cards = await (_db.select(_db.cards)
            ..where((c) => c.id.isIn(cardIds) & c.deletedAt.isNull()))
          .get();
      await (_db.update(_db.cards)..where(
            (c) => c.id.isIn(cardIds) & c.deletedAt.isNull(),
          ))
          .write(
            CardsCompanion(
              deletedAt: Value<DateTime>(now),
              updatedAt: Value<DateTime>(now),
            ),
          );
      for (final CardRow card in cards) {
        await _enqueue('cards', card.id, SyncOperation.delete);
      }
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

    final query = _db.select(_db.cards).join([
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
    final matches = _db.select(_db.cards).join([
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
        _toCard(row.readTable(_db.cards), row.readTableOrNull(_db.cardStates)),
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
      type: card.type.name,
      due: state?.due,
      lapses: state?.lapses ?? 0,
      scheduledDays: state?.scheduledDays ?? 0,
      suspended:
          state?.status == CardStatus.suspended ||
          state?.status == CardStatus.buried,
      favorite: card.favorite,
      occlusion: card.occlusion,
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
      final CardStateRow? previous = await (_db.select(
        _db.cardStates,
      )..where((s) => s.cardId.equals(cardId))).getSingleOrNull();

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

  /// Pushes a card's next review into the future without rating it.
  ///
  /// Used by the "postpone" action in the review screen. The card leaves the
  /// current queue and returns as a learning card after [duration].
  Future<void> snoozeCard({
    required String cardId,
    Duration duration = const Duration(minutes: 10),
  }) {
    return _db.transaction(() async {
      final DateTime now = _clock();
      final CardStateRow? previous = await (_db.select(
        _db.cardStates,
      )..where((s) => s.cardId.equals(cardId))).getSingleOrNull();
      await _db
          .into(_db.cardStates)
          .insertOnConflictUpdate(
            CardStatesCompanion(
              cardId: Value(cardId),
              status: Value(CardStatus.learning),
              due: Value(now.add(duration)),
              elapsedDays: Value(previous?.elapsedDays ?? 0),
              scheduledDays: Value(0),
              reps: Value(previous?.reps ?? 0),
              lapses: Value(previous?.lapses ?? 0),
              lastReview: Value(previous?.lastReview ?? now),
              updatedAt: Value(now),
            ),
          );
      await _enqueue('card_states', cardId, SyncOperation.upsert);
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

  /// One row per day that has at least one review, oldest first.
  Stream<List<ReviewActivityDay>> watchReviewActivity() {
    final Selectable<QueryRow> query = _db.customSelect(
      "SELECT date(reviewed_at, 'unixepoch', 'localtime') AS day, "
      'COUNT(*) AS reviews, '
      'COALESCE(SUM(CASE WHEN rating >= 2 THEN 1 ELSE 0 END), 0) AS correct '
      'FROM review_logs GROUP BY day ORDER BY day',
      readsFrom: {_db.reviewLogs},
    );
    return query.watch().map((List<QueryRow> rows) {
      return <ReviewActivityDay>[
        for (final QueryRow row in rows)
          ReviewActivityDay(
            day: DateTime.parse(row.read<String>('day')),
            reviews: row.read<int>('reviews'),
            correct: row.read<int>('correct'),
          ),
      ];
    });
  }

  /// Cards due on each of the next [days] days. Overdue cards are counted
  /// against today so the forecast never hides work that is already late.
  Stream<List<DueForecastDay>> watchDueForecast({int days = 7}) {
    final DateTime now = _clock();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime horizon = today.add(Duration(days: days));
    final Selectable<QueryRow> query = _db.customSelect(
      "SELECT date(s.due, 'unixepoch', 'localtime') AS day, "
      'COUNT(*) AS total '
      'FROM card_states s JOIN cards c ON c.id = s.card_id '
      'WHERE c.deleted_at IS NULL '
      "AND s.status IN ('learning', 'relearning', 'review') "
      'AND s.due < ? GROUP BY day ORDER BY day',
      variables: <Variable<Object>>[
        Variable<int>(horizon.millisecondsSinceEpoch ~/ 1000),
      ],
      readsFrom: {_db.cardStates, _db.cards},
    );
    return query.watch().map((List<QueryRow> rows) {
      final Map<String, int> counts = <String, int>{};
      for (final QueryRow row in rows) {
        final DateTime day = DateTime.parse(row.read<String>('day'));
        final int count = row.read<int>('total');
        if (day.isBefore(today)) {
          counts[_dayKey(today)] = (counts[_dayKey(today)] ?? 0) + count;
        } else {
          counts[_dayKey(day)] = (counts[_dayKey(day)] ?? 0) + count;
        }
      }
      return <DueForecastDay>[
        for (int index = 0; index < days; index++)
          DueForecastDay(
            day: today.add(Duration(days: index)),
            count: counts[_dayKey(today.add(Duration(days: index)))] ?? 0,
          ),
      ];
    });
  }

  /// Real totals for one deck. A main deck includes its sub-decks.
  Stream<DeckStatistics> watchDeckStatistics(String deckId) {
    final Selectable<QueryRow> query = _db.customSelect(
      'WITH subtree(id) AS ('
      '  SELECT id FROM decks WHERE id = ? AND deleted_at IS NULL '
      '  UNION ALL '
      '  SELECT id FROM decks WHERE parent_id = ? AND deleted_at IS NULL'
      ') '
      'SELECT '
      '  COUNT(c.id) AS total_cards, '
      '  COALESCE(SUM(CASE WHEN s.card_id IS NULL OR s.status = \'newCard\' '
      '    THEN 1 ELSE 0 END), 0) AS new_cards, '
      '  COALESCE(SUM(CASE WHEN s.status IN (\'learning\', \'relearning\') '
      '    THEN 1 ELSE 0 END), 0) AS learning_cards, '
      '  COALESCE(SUM(CASE WHEN s.status IN (\'learning\', \'relearning\', '
      '    \'review\') AND s.due <= CAST(strftime(\'%s\', \'now\') AS INTEGER) '
      '    THEN 1 ELSE 0 END), 0) AS due_cards, '
      '  COALESCE(SUM(CASE WHEN s.status = \'review\' '
      '    AND s.scheduled_days >= 21 THEN 1 ELSE 0 END), 0) AS mature_cards, '
      '  (SELECT COUNT(*) FROM review_logs r '
      '    JOIN cards rc ON rc.id = r.card_id '
      '    WHERE rc.deleted_at IS NULL '
      '      AND rc.deck_id IN (SELECT id FROM subtree)) AS review_count, '
      '  (SELECT COUNT(*) FROM review_logs r '
      '    JOIN cards rc ON rc.id = r.card_id '
      '    WHERE rc.deleted_at IS NULL AND r.rating >= 2 '
      '      AND rc.deck_id IN (SELECT id FROM subtree)) AS correct_count '
      'FROM cards c '
      'LEFT JOIN card_states s ON s.card_id = c.id '
      'WHERE c.deleted_at IS NULL AND c.deck_id IN (SELECT id FROM subtree)',
      variables: <Variable<Object>>[
        Variable<String>(deckId),
        Variable<String>(deckId),
      ],
      readsFrom: {_db.decks, _db.cards, _db.cardStates, _db.reviewLogs},
    );
    return query.watch().map((List<QueryRow> rows) {
      if (rows.isEmpty) {
        return const DeckStatistics();
      }
      final QueryRow row = rows.first;
      return DeckStatistics(
        totalCards: row.read<int>('total_cards'),
        newCards: row.read<int>('new_cards'),
        learningCards: row.read<int>('learning_cards'),
        dueCards: row.read<int>('due_cards'),
        matureCards: row.read<int>('mature_cards'),
        reviewCount: row.read<int>('review_count'),
        correctCount: row.read<int>('correct_count'),
      );
    });
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

  CardType _cardTypeFromName(String value) {
    return CardType.values.firstWhere(
      (CardType type) => type.name == value,
      orElse: () => CardType.basic,
    );
  }

  DeckNode _deckNodeFromRow(DeckRow row, {int cardCount = 0}) {
    return DeckNode(
      id: row.id,
      parentId: row.parentId,
      rootId: row.rootId,
      depth: row.depth,
      position: row.position,
      title: row.title,
      description: row.description,
      color: colorFromHex(row.colorHex),
      iconKey: row.icon,
      tags: row.tags,
      privacy: row.privacy,
      isPublic: row.privacy == DeckPrivacy.public,
      publishedAt: row.publishedAt,
      sourceDeckId: row.sourceDeckId,
      ownCardCount: cardCount,
      cardCount: cardCount,
    );
  }

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
    required this.mastered,
    required this.dueNew,
    required this.dueLearning,
    required this.dueReview,
    required this.reviews,
    required this.correct,
  });

  final DeckRow deck;
  final int ownCards;
  final int mastered;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviews;
  final int correct;
}

class _Totals {
  const _Totals({
    required this.cards,
    required this.mastered,
    required this.dueNew,
    required this.dueLearning,
    required this.dueReview,
    required this.reviews,
    required this.correct,
  });

  final int cards;
  final int mastered;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviews;
  final int correct;
}
