import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/enums.dart';
import '../domain/fsrs.dart';
import '../domain/models.dart';
import 'local/app_database.dart';
import 'starter_content.dart';

class ContentFailure implements Exception {
  const ContentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The single write path for local content.
///
/// Every mutation updates the local row and appends an outbox event in the same
/// transaction. The UI can therefore stay fully offline; Phase 2 only has to
/// drain [SyncOutbox] into Supabase.
class ContentRepository {
  ContentRepository({
    AppDatabase? database,
    Uuid? uuid,
    FsrsScheduler? scheduler,
  }) : _db = database ?? AppDatabase(),
       _uuid = uuid ?? Uuid(),
       _scheduler = scheduler ?? FsrsScheduler();

  static const String _starterSeedKey = 'starter_seed_version';
  static const int _starterSeedVersion = 1;

  final AppDatabase _db;
  final Uuid _uuid;
  final FsrsScheduler _scheduler;

  AppDatabase get database => _db;

  Future<void> seedIfNeeded({required String languageCode}) async {
    final MetadataRecord? existingSeed = await (_db.select(
      _db.metadata,
    )..where((Metadata t) => t.key.equals(_starterSeedKey))).getSingleOrNull();
    if (existingSeed != null) {
      return;
    }

    final DeckRecord? firstDeck =
        await (_db.select(_db.decks)
              ..where((Decks t) => t.deletedAtMs.isNull())
              ..limit(1))
            .getSingleOrNull();

    if (firstDeck == null) {
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final List<DecksCompanion> deckRows = <DecksCompanion>[];
      final List<CardsCompanion> cardRows = <CardsCompanion>[];

      for (
        int deckIndex = 0;
        deckIndex < StarterCatalog.decks.length;
        deckIndex += 1
      ) {
        final StarterDeck template = StarterCatalog.decks[deckIndex];
        final String rootId = _uuid.v4();
        deckRows.add(
          DecksCompanion(
            id: Value<String>(rootId),
            parentId: const Value<String?>(null),
            title: Value<String>(template.title(languageCode)),
            description: Value<String>(template.description(languageCode)),
            colorHex: Value<String>(template.colorHex),
            iconKey: Value<String>(template.iconKey),
            privacy: const Value<DeckPrivacy>(DeckPrivacy.private),
            tagsJson: Value<String>(_encodeTags(template.tags)),
            isStarter: const Value<bool>(true),
            isArchived: const Value<bool>(false),
            position: Value<int>(deckIndex),
            depth: const Value<int>(0),
            sourceTemplateId: Value<String?>(template.id),
            createdAtMs: Value<int>(now),
            updatedAtMs: Value<int>(now),
            publishedAtMs: const Value<int?>(null),
            deletedAtMs: const Value<int?>(null),
            isDirty: const Value<bool>(true),
          ),
        );

        for (
          int lessonIndex = 0;
          lessonIndex < template.lessons.length;
          lessonIndex += 1
        ) {
          final StarterLesson lesson = template.lessons[lessonIndex];
          final String lessonId = _uuid.v4();
          deckRows.add(
            DecksCompanion(
              id: Value<String>(lessonId),
              parentId: Value<String?>(rootId),
              title: Value<String>(lesson.title(languageCode)),
              description: const Value<String>(''),
              colorHex: Value<String>(template.colorHex),
              iconKey: const Value<String>('layers'),
              privacy: const Value<DeckPrivacy>(DeckPrivacy.private),
              tagsJson: Value<String>(_encodeTags(template.tags)),
              isStarter: const Value<bool>(true),
              isArchived: const Value<bool>(false),
              position: Value<int>(lessonIndex),
              depth: const Value<int>(1),
              sourceTemplateId: Value<String?>(template.id),
              createdAtMs: Value<int>(now),
              updatedAtMs: Value<int>(now),
              publishedAtMs: const Value<int?>(null),
              deletedAtMs: const Value<int?>(null),
              isDirty: const Value<bool>(true),
            ),
          );

          for (
            int cardIndex = 0;
            cardIndex < lesson.cards.length;
            cardIndex += 1
          ) {
            final StarterCard card = lesson.cards[cardIndex];
            cardRows.add(
              CardsCompanion(
                id: Value<String>(_uuid.v4()),
                deckId: Value<String>(lessonId),
                kind: const Value<CardKind>(CardKind.basic),
                front: Value<String>(card.cardFront),
                back: Value<String>(card.back),
                hint: Value<String>(card.hint),
                notes: Value<String>(card.notes),
                tagsJson: Value<String>(_encodeTags(card.tags)),
                position: Value<int>(cardIndex),
                createdAtMs: Value<int>(now),
                updatedAtMs: Value<int>(now),
                deletedAtMs: const Value<int?>(null),
                isDirty: const Value<bool>(true),
              ),
            );
          }
        }
      }

      await _db.batch((Batch batch) {
        batch.insertAll(_db.decks, deckRows);
        batch.insertAll(_db.cards, cardRows);
      });
    }

    await _db
        .into(_db.metadata)
        .insertOnConflictUpdate(
          MetadataCompanion(
            key: Value<String>(_starterSeedKey),
            value: Value<String>('$_starterSeedVersion'),
          ),
        );
  }

  Future<Catalog> loadCatalog({String? displayName}) async {
    final List<DeckRecord> deckRows =
        await (_db.select(_db.decks)
              ..where((Decks t) => t.deletedAtMs.isNull())
              ..orderBy(<OrderingTerm Function(Decks)>[
                (Decks t) => OrderingTerm.asc(t.position),
                (Decks t) => OrderingTerm.asc(t.title),
              ]))
            .get();
    final List<CardRecord> cardRows =
        await (_db.select(_db.cards)
              ..where((Cards t) => t.deletedAtMs.isNull())
              ..orderBy(<OrderingTerm Function(Cards)>[
                (Cards t) => OrderingTerm.asc(t.position),
                (Cards t) => OrderingTerm.asc(t.createdAtMs),
              ]))
            .get();
    final List<CardStateRecord> stateRows = await _db
        .select(_db.cardStates)
        .get();
    final List<ReviewLogRecord> logRows =
        await (_db.select(_db.reviewLogs)
              ..orderBy(<OrderingTerm Function(ReviewLogs)>[
                (ReviewLogs t) => OrderingTerm.asc(t.reviewedAtMs),
              ]))
            .get();

    final Map<String, CardStateRecord> states = <String, CardStateRecord>{
      for (final CardStateRecord row in stateRows) row.cardId: row,
    };
    final Map<String, List<CardSummary>> cardsByDeck =
        <String, List<CardSummary>>{};
    final Map<String, CardSummary> cardById = <String, CardSummary>{};

    for (final CardRecord row in cardRows) {
      final CardStateRecord? state = states[row.id];
      final CardSummary card = CardSummary(
        id: row.id,
        deckId: row.deckId,
        front: row.cardFront,
        back: row.back,
        hint: row.hint,
        notes: row.notes,
        kind: row.kind,
        tags: _decodeTags(row.tagsJson),
        position: row.position,
        createdAt: _date(row.createdAtMs),
        updatedAt: _date(row.updatedAtMs),
        fsrs: state == null
            ? FsrsCard.newCard(_date(row.createdAtMs))
            : _fsrsFromState(state),
        isSuspended: state?.isSuspended ?? false,
        isBuried: state?.isBuried ?? false,
      );
      cardById[card.id] = card;
      cardsByDeck.putIfAbsent(card.deckId, () => <CardSummary>[]).add(card);
    }

    final Map<String, _DeckBuilder> builders = <String, _DeckBuilder>{
      for (final DeckRecord row in deckRows) row.id: _DeckBuilder(row),
    };
    final List<_DeckBuilder> rootBuilders = <_DeckBuilder>[];

    for (final DeckRecord row in deckRows) {
      final _DeckBuilder builder = builders[row.id]!;
      final _DeckBuilder? parent = row.parentId == null
          ? null
          : builders[row.parentId];
      if (parent == null) {
        rootBuilders.add(builder);
      } else {
        parent.children.add(builder);
      }
    }

    _sortBuilders(rootBuilders);

    final DateTime now = DateTime.now().toUtc();
    for (final _DeckBuilder root in rootBuilders) {
      _aggregate(root, cardsByDeck, now);
    }

    final List<DeckNode> allDecks = <DeckNode>[];
    final Map<String, DeckNode> deckById = <String, DeckNode>{};

    DeckNode buildNode(_DeckBuilder builder) {
      final List<DeckNode> children = builder.children
          .map(buildNode)
          .toList(growable: false);
      final DeckNode node = DeckNode(
        summary: _summaryFor(builder, cardsByDeck),
        children: children,
      );
      allDecks.add(node);
      deckById[node.summary.id] = node;
      return node;
    }

    final List<DeckNode> roots = rootBuilders
        .map(buildNode)
        .toList(growable: false);
    allDecks.sort((DeckNode a, DeckNode b) {
      final int byDepth = a.summary.depth.compareTo(b.summary.depth);
      if (byDepth != 0) {
        return byDepth;
      }
      return a.summary.title.compareTo(b.summary.title);
    });

    final List<ReviewEvent> reviews = <ReviewEvent>[];
    for (final ReviewLogRecord row in logRows) {
      final CardSummary? card = cardById[row.cardId];
      if (card == null) {
        continue;
      }
      final int ratingIndex = (row.rating - 1).clamp(0, 3).toInt();
      reviews.add(
        ReviewEvent(
          id: row.id,
          cardId: row.cardId,
          deckId: card.deckId,
          rating: FsrsRating.values[ratingIndex],
          reviewedAt: _date(row.reviewedAtMs),
          scheduledDays: row.scheduledDays,
          stability: row.stability ?? 0,
          difficulty: row.difficulty ?? 0,
          elapsedMs: row.elapsedMs,
        ),
      );
    }

    return Catalog(
      roots: roots,
      allDecks: allDecks,
      deckById: deckById,
      cardsByDeck: cardsByDeck,
      cardById: cardById,
      reviews: reviews,
      generatedAt: now,
      displayName: displayName,
    );
  }

  Future<String> createDeck({
    required String title,
    String? parentId,
    String description = '',
    String colorHex = '#1D6FD1',
    String iconKey = 'layers',
    List<String> tags = const <String>[],
    DeckPrivacy? privacy,
  }) async {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ContentFailure('العنوان مطلوب.');
    }
    return _db.transaction(() async {
      final DeckRecord? parent = parentId == null
          ? null
          : await _getDeckRow(parentId);
      if (parentId != null && parent == null) {
        throw const ContentFailure('المجلد الأب غير موجود.');
      }
      final int position = await _nextDeckPosition(parentId);
      final int depth = parent == null ? 0 : parent.depth + 1;
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final String id = _uuid.v4();
      final DeckPrivacy actualPrivacy =
          privacy ?? parent?.privacy ?? DeckPrivacy.private;
      final DeckRecord record = DeckRecord(
        id: id,
        parentId: parentId,
        title: cleanTitle,
        description: description.trim(),
        colorHex: colorHex,
        iconKey: iconKey,
        privacy: actualPrivacy,
        tagsJson: _encodeTags(tags),
        isStarter: false,
        isArchived: false,
        position: position,
        depth: depth,
        sourceTemplateId: null,
        createdAtMs: now,
        updatedAtMs: now,
        publishedAtMs: null,
        deletedAtMs: null,
        isDirty: true,
      );
      await _db
          .into(_db.decks)
          .insert(
            DecksCompanion(
              id: Value<String>(id),
              parentId: Value<String?>(parentId),
              title: Value<String>(cleanTitle),
              description: Value<String>(description.trim()),
              colorHex: Value<String>(colorHex),
              iconKey: Value<String>(iconKey),
              privacy: Value<DeckPrivacy>(actualPrivacy),
              tagsJson: Value<String>(_encodeTags(tags)),
              isStarter: const Value<bool>(false),
              isArchived: const Value<bool>(false),
              position: Value<int>(position),
              depth: Value<int>(depth),
              sourceTemplateId: const Value<String?>(null),
              createdAtMs: Value<int>(now),
              updatedAtMs: Value<int>(now),
              publishedAtMs: const Value<int?>(null),
              deletedAtMs: const Value<int?>(null),
              isDirty: const Value<bool>(true),
            ),
          );
      await _enqueue('deck', id, 'create', _deckPayload(record));
      return id;
    });
  }

  Future<void> updateDeck(
    String id, {
    String? title,
    String? description,
    String? colorHex,
    String? iconKey,
    List<String>? tags,
    DeckPrivacy? privacy,
    bool? isArchived,
  }) async {
    final String? cleanTitle = title?.trim();
    if (title != null && cleanTitle!.isEmpty) {
      throw const ContentFailure('العنوان مطلوب.');
    }
    await _db.transaction(() async {
      final DeckRecord? existing = await _getDeckRow(id);
      if (existing == null) {
        throw const ContentFailure('المجلد غير موجود.');
      }
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(_db.decks)..where((Decks t) => t.id.equals(id))).write(
        DecksCompanion(
          title: title == null
              ? const Value<String>.absent()
              : Value<String>(cleanTitle!),
          description: description == null
              ? const Value<String>.absent()
              : Value<String>(description.trim()),
          colorHex: colorHex == null
              ? const Value<String>.absent()
              : Value<String>(colorHex),
          iconKey: iconKey == null
              ? const Value<String>.absent()
              : Value<String>(iconKey),
          tagsJson: tags == null
              ? const Value<String>.absent()
              : Value<String>(_encodeTags(tags)),
          privacy: privacy == null
              ? const Value<DeckPrivacy>.absent()
              : Value<DeckPrivacy>(privacy),
          isArchived: isArchived == null
              ? const Value<bool>.absent()
              : Value<bool>(isArchived),
          updatedAtMs: Value<int>(now),
          isDirty: const Value<bool>(true),
        ),
      );
      if (privacy != null && privacy != existing.privacy) {
        await _setPrivacySubtree(id, privacy, now, includeSelf: false);
      }
      final DeckRecord? updated = await _getDeckRow(id);
      if (updated != null) {
        await _enqueue('deck', id, 'update', _deckPayload(updated));
      }
    });
  }

  Future<void> setDeckPrivacy(String id, DeckPrivacy privacy) async {
    await _db.transaction(() async {
      final DeckRecord? existing = await _getDeckRow(id);
      if (existing == null) {
        throw const ContentFailure('المجلد غير موجود.');
      }
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _setPrivacySubtree(id, privacy, now);
      final DeckRecord? updated = await _getDeckRow(id);
      if (updated != null) {
        await _enqueue('deck', id, 'update', _deckPayload(updated));
      }
    });
  }

  Future<void> deleteDeck(String id) async {
    await _db.transaction(() async {
      final List<DeckRecord> allDecks = await (_db.select(
        _db.decks,
      )..where((Decks t) => t.deletedAtMs.isNull())).get();
      final Set<String> ids = <String>{id};
      bool changed = true;
      while (changed) {
        changed = false;
        for (final DeckRecord row in allDecks) {
          if (row.parentId != null &&
              ids.contains(row.parentId) &&
              !ids.contains(row.id)) {
            ids.add(row.id);
            changed = true;
          }
        }
      }
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (final String deckId in ids) {
        DeckRecord? deck;
        for (final DeckRecord row in allDecks) {
          if (row.id == deckId) {
            deck = row;
            break;
          }
        }
        if (deck == null) {
          continue;
        }
        await (_db.update(
          _db.decks,
        )..where((Decks t) => t.id.equals(deckId))).write(
          DecksCompanion(
            deletedAtMs: Value<int>(now),
            updatedAtMs: Value<int>(now),
            isDirty: const Value<bool>(true),
          ),
        );
        await _enqueue(
          'deck',
          deckId,
          'delete',
          _deckPayload(deck, deletedAtMs: now),
        );

        final List<CardRecord> cardRows =
            await (_db.select(_db.cards)..where(
                  (Cards t) => t.deckId.equals(deckId) & t.deletedAtMs.isNull(),
                ))
                .get();
        for (final CardRecord card in cardRows) {
          await (_db.update(
            _db.cards,
          )..where((Cards t) => t.id.equals(card.id))).write(
            CardsCompanion(
              deletedAtMs: Value<int>(now),
              updatedAtMs: Value<int>(now),
              isDirty: const Value<bool>(true),
            ),
          );
          await _enqueue(
            'card',
            card.id,
            'delete',
            _cardPayload(card, deletedAtMs: now),
          );
        }
      }
    });
  }

  Future<String> createCard({
    required String deckId,
    required String front,
    required String back,
    String hint = '',
    String notes = '',
    List<String> tags = const <String>[],
    CardKind kind = CardKind.basic,
  }) async {
    final String cleanFront = front.trim();
    final String cleanBack = back.trim();
    if (cleanFront.isEmpty || cleanBack.isEmpty) {
      throw const ContentFailure('وجه البطاقة وظهرها مطلوبان.');
    }
    return _db.transaction(() async {
      final DeckRecord? deck = await _getDeckRow(deckId);
      if (deck == null) {
        throw const ContentFailure('المجلد غير موجود.');
      }
      final int position = await _nextCardPosition(deckId);
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final String id = _uuid.v4();
      final CardRecord record = CardRecord(
        id: id,
        deckId: deckId,
        kind: kind,
        front: cleanFront,
        back: cleanBack,
        hint: hint.trim(),
        notes: notes.trim(),
        tagsJson: _encodeTags(tags),
        position: position,
        createdAtMs: now,
        updatedAtMs: now,
        deletedAtMs: null,
        isDirty: true,
      );
      await _db
          .into(_db.cards)
          .insert(
            CardsCompanion(
              id: Value<String>(id),
              deckId: Value<String>(deckId),
              kind: Value<CardKind>(kind),
              front: Value<String>(cleanFront),
              back: Value<String>(cleanBack),
              hint: Value<String>(hint.trim()),
              notes: Value<String>(notes.trim()),
              tagsJson: Value<String>(_encodeTags(tags)),
              position: Value<int>(position),
              createdAtMs: Value<int>(now),
              updatedAtMs: Value<int>(now),
              deletedAtMs: const Value<int?>(null),
              isDirty: const Value<bool>(true),
            ),
          );
      await _enqueue('card', id, 'create', _cardPayload(record));
      return id;
    });
  }

  Future<void> updateCard(
    String id, {
    String? front,
    String? back,
    String? hint,
    String? notes,
    List<String>? tags,
    CardKind? kind,
  }) async {
    final String? cleanFront = front?.trim();
    final String? cleanBack = back?.trim();
    if (front != null && cleanFront!.isEmpty) {
      throw const ContentFailure('وجه البطاقة مطلوب.');
    }
    if (back != null && cleanBack!.isEmpty) {
      throw const ContentFailure('ظهر البطاقة مطلوب.');
    }
    await _db.transaction(() async {
      final CardRecord? existing = await _getCardRow(id);
      if (existing == null) {
        throw const ContentFailure('البطاقة غير موجودة.');
      }
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(_db.cards)..where((Cards t) => t.id.equals(id))).write(
        CardsCompanion(
          front: front == null
              ? const Value<String>.absent()
              : Value<String>(cleanFront!),
          back: back == null
              ? const Value<String>.absent()
              : Value<String>(cleanBack!),
          hint: hint == null
              ? const Value<String>.absent()
              : Value<String>(hint.trim()),
          notes: notes == null
              ? const Value<String>.absent()
              : Value<String>(notes.trim()),
          tagsJson: tags == null
              ? const Value<String>.absent()
              : Value<String>(_encodeTags(tags)),
          kind: kind == null
              ? const Value<CardKind>.absent()
              : Value<CardKind>(kind),
          updatedAtMs: Value<int>(now),
          isDirty: const Value<bool>(true),
        ),
      );
      final CardRecord? updated = await _getCardRow(id);
      if (updated != null) {
        await _enqueue('card', id, 'update', _cardPayload(updated));
      }
    });
  }

  Future<void> deleteCard(String id) async {
    await _db.transaction(() async {
      final CardRecord? card = await _getCardRow(id);
      if (card == null) {
        return;
      }
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(_db.cards)..where((Cards t) => t.id.equals(id))).write(
        CardsCompanion(
          deletedAtMs: Value<int>(now),
          updatedAtMs: Value<int>(now),
          isDirty: const Value<bool>(true),
        ),
      );
      await _enqueue(
        'card',
        id,
        'delete',
        _cardPayload(card, deletedAtMs: now),
      );
    });
  }

  Future<int> importCards({
    required String deckId,
    required List<ImportedCard> cards,
  }) async {
    if (cards.isEmpty) {
      return 0;
    }
    return _db.transaction(() async {
      final DeckRecord? deck = await _getDeckRow(deckId);
      if (deck == null) {
        throw const ContentFailure('المجلد غير موجود.');
      }
      int position = await _nextCardPosition(deckId);
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      int count = 0;
      for (final ImportedCard input in cards) {
        final String front = input.cardFront.trim();
        final String back = input.back.trim();
        if (front.isEmpty || back.isEmpty) {
          continue;
        }
        final String id = _uuid.v4();
        final CardRecord record = CardRecord(
          id: id,
          deckId: deckId,
          kind: CardKind.basic,
          front: front,
          back: back,
          hint: input.hint.trim(),
          notes: input.notes.trim(),
          tagsJson: _encodeTags(input.tags),
          position: position,
          createdAtMs: now,
          updatedAtMs: now,
          deletedAtMs: null,
          isDirty: true,
        );
        await _db
            .into(_db.cards)
            .insert(
              CardsCompanion(
                id: Value<String>(id),
                deckId: Value<String>(deckId),
                kind: const Value<CardKind>(CardKind.basic),
                front: Value<String>(front),
                back: Value<String>(back),
                hint: Value<String>(input.hint.trim()),
                notes: Value<String>(input.notes.trim()),
                tagsJson: Value<String>(_encodeTags(input.tags)),
                position: Value<int>(position),
                createdAtMs: Value<int>(now),
                updatedAtMs: Value<int>(now),
                deletedAtMs: const Value<int?>(null),
                isDirty: const Value<bool>(true),
              ),
            );
        await _enqueue('card', id, 'create', _cardPayload(record));
        position += 1;
        count += 1;
      }
      return count;
    });
  }

  Future<String> installStarter(
    String templateId, {
    required String languageCode,
  }) async {
    final StarterDeck? template = StarterCatalog.byId(templateId);
    if (template == null) {
      throw const ContentFailure('المحتوى غير موجود.');
    }
    return _db.transaction(() async {
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final String rootId = _uuid.v4();
      final int rootPosition = await _nextDeckPosition(null);
      final DeckRecord root = DeckRecord(
        id: rootId,
        parentId: null,
        title: template.title(languageCode),
        description: template.description(languageCode),
        colorHex: template.colorHex,
        iconKey: template.iconKey,
        privacy: DeckPrivacy.private,
        tagsJson: _encodeTags(template.tags),
        isStarter: false,
        isArchived: false,
        position: rootPosition,
        depth: 0,
        sourceTemplateId: template.id,
        createdAtMs: now,
        updatedAtMs: now,
        publishedAtMs: null,
        deletedAtMs: null,
        isDirty: true,
      );
      await _db
          .into(_db.decks)
          .insert(
            DecksCompanion(
              id: Value<String>(rootId),
              parentId: const Value<String?>(null),
              title: Value<String>(root.title),
              description: Value<String>(root.description),
              colorHex: Value<String>(root.colorHex),
              iconKey: Value<String>(root.iconKey),
              privacy: const Value<DeckPrivacy>(DeckPrivacy.private),
              tagsJson: Value<String>(root.tagsJson),
              isStarter: const Value<bool>(false),
              isArchived: const Value<bool>(false),
              position: Value<int>(rootPosition),
              depth: const Value<int>(0),
              sourceTemplateId: Value<String?>(template.id),
              createdAtMs: Value<int>(now),
              updatedAtMs: Value<int>(now),
              publishedAtMs: const Value<int?>(null),
              deletedAtMs: const Value<int?>(null),
              isDirty: const Value<bool>(true),
            ),
          );
      await _enqueue('deck', rootId, 'create', _deckPayload(root));

      for (
        int lessonIndex = 0;
        lessonIndex < template.lessons.length;
        lessonIndex += 1
      ) {
        final StarterLesson lesson = template.lessons[lessonIndex];
        final String lessonId = _uuid.v4();
        final DeckRecord lessonRecord = DeckRecord(
          id: lessonId,
          parentId: rootId,
          title: lesson.title(languageCode),
          description: '',
          colorHex: template.colorHex,
          iconKey: 'layers',
          privacy: DeckPrivacy.private,
          tagsJson: _encodeTags(template.tags),
          isStarter: false,
          isArchived: false,
          position: lessonIndex,
          depth: 1,
          sourceTemplateId: template.id,
          createdAtMs: now,
          updatedAtMs: now,
          publishedAtMs: null,
          deletedAtMs: null,
          isDirty: true,
        );
        await _db
            .into(_db.decks)
            .insert(
              DecksCompanion(
                id: Value<String>(lessonId),
                parentId: Value<String?>(rootId),
                title: Value<String>(lessonRecord.title),
                description: const Value<String>(''),
                colorHex: Value<String>(template.colorHex),
                iconKey: const Value<String>('layers'),
                privacy: const Value<DeckPrivacy>(DeckPrivacy.private),
                tagsJson: Value<String>(lessonRecord.tagsJson),
                isStarter: const Value<bool>(false),
                isArchived: const Value<bool>(false),
                position: Value<int>(lessonIndex),
                depth: const Value<int>(1),
                sourceTemplateId: Value<String?>(template.id),
                createdAtMs: Value<int>(now),
                updatedAtMs: Value<int>(now),
                publishedAtMs: const Value<int?>(null),
                deletedAtMs: const Value<int?>(null),
                isDirty: const Value<bool>(true),
              ),
            );
        await _enqueue('deck', lessonId, 'create', _deckPayload(lessonRecord));

        for (
          int cardIndex = 0;
          cardIndex < lesson.cards.length;
          cardIndex += 1
        ) {
          final StarterCard card = lesson.cards[cardIndex];
          final String cardId = _uuid.v4();
          final CardRecord cardRecord = CardRecord(
            id: cardId,
            deckId: lessonId,
            kind: CardKind.basic,
            front: card.cardFront,
            back: card.back,
            hint: card.hint,
            notes: card.notes,
            tagsJson: _encodeTags(card.tags),
            position: cardIndex,
            createdAtMs: now,
            updatedAtMs: now,
            deletedAtMs: null,
            isDirty: true,
          );
          await _db
              .into(_db.cards)
              .insert(
                CardsCompanion(
                  id: Value<String>(cardId),
                  deckId: Value<String>(lessonId),
                  kind: const Value<CardKind>(CardKind.basic),
                  front: Value<String>(card.cardFront),
                  back: Value<String>(card.back),
                  hint: Value<String>(card.hint),
                  notes: Value<String>(card.notes),
                  tagsJson: Value<String>(_encodeTags(card.tags)),
                  position: Value<int>(cardIndex),
                  createdAtMs: Value<int>(now),
                  updatedAtMs: Value<int>(now),
                  deletedAtMs: const Value<int?>(null),
                  isDirty: const Value<bool>(true),
                ),
              );
          await _enqueue('card', cardId, 'create', _cardPayload(cardRecord));
        }
      }
      return rootId;
    });
  }

  Future<String> duplicateDeckTree(
    String sourceId, {
    String? targetParentId,
    String? rootTitle,
    bool includeProgress = false,
  }) async {
    return _db.transaction(() async {
      final DeckRecord? source = await _getDeckRow(sourceId);
      if (source == null) {
        throw const ContentFailure('المجلد غير موجود.');
      }
      final DeckRecord? targetParent = targetParentId == null
          ? null
          : await _getDeckRow(targetParentId);
      if (targetParentId != null && targetParent == null) {
        throw const ContentFailure('المجلد الهدف غير موجود.');
      }

      final List<DeckRecord> allDecks = await (_db.select(
        _db.decks,
      )..where((Decks t) => t.deletedAtMs.isNull())).get();
      final List<DeckRecord> subtree = <DeckRecord>[source];
      bool changed = true;
      while (changed) {
        changed = false;
        for (final DeckRecord candidate in allDecks) {
          if (candidate.parentId != null &&
              subtree.any((DeckRecord d) => d.id == candidate.parentId) &&
              !subtree.any((DeckRecord d) => d.id == candidate.id)) {
            subtree.add(candidate);
            changed = true;
          }
        }
      }

      final Map<String, String> newIds = <String, String>{
        for (final DeckRecord deck in subtree) deck.id: _uuid.v4(),
      };
      final String newRootId = newIds[sourceId]!;
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final int rootDepth = targetParent == null ? 0 : targetParent.depth + 1;
      final int rootPosition = await _nextDeckPosition(targetParentId);
      final Map<String, int> newDepths = <String, int>{};

      for (final DeckRecord deck in subtree) {
        final bool isRoot = deck.id == sourceId;
        final String? newParentId = isRoot
            ? targetParentId
            : newIds[deck.parentId];
        if (!isRoot && newParentId == null) {
          continue;
        }
        final int depth = isRoot
            ? rootDepth
            : (newDepths[deck.parentId] ?? rootDepth) + 1;
        newDepths[deck.id] = depth;
        final String title = isRoot && rootTitle != null
            ? rootTitle
            : deck.title;
        final DeckRecord record = DeckRecord(
          id: newIds[deck.id]!,
          parentId: newParentId,
          title: title,
          description: deck.description,
          colorHex: deck.colorHex,
          iconKey: deck.iconKey,
          privacy: DeckPrivacy.private,
          tagsJson: deck.tagsJson,
          isStarter: false,
          isArchived: false,
          position: isRoot ? rootPosition : deck.position,
          depth: depth,
          sourceTemplateId: deck.sourceTemplateId,
          createdAtMs: now,
          updatedAtMs: now,
          publishedAtMs: null,
          deletedAtMs: null,
          isDirty: true,
        );
        await _db
            .into(_db.decks)
            .insert(
              DecksCompanion(
                id: Value<String>(record.id),
                parentId: Value<String?>(record.parentId),
                title: Value<String>(record.title),
                description: Value<String>(record.description),
                colorHex: Value<String>(record.colorHex),
                iconKey: Value<String>(record.iconKey),
                privacy: const Value<DeckPrivacy>(DeckPrivacy.private),
                tagsJson: Value<String>(record.tagsJson),
                isStarter: const Value<bool>(false),
                isArchived: const Value<bool>(false),
                position: Value<int>(record.position),
                depth: Value<int>(record.depth),
                sourceTemplateId: Value<String?>(record.sourceTemplateId),
                createdAtMs: Value<int>(now),
                updatedAtMs: Value<int>(now),
                publishedAtMs: const Value<int?>(null),
                deletedAtMs: const Value<int?>(null),
                isDirty: const Value<bool>(true),
              ),
            );
        await _enqueue('deck', record.id, 'create', _deckPayload(record));

        final List<CardRecord> sourceCards =
            await (_db.select(_db.cards)
                  ..where(
                    (Cards t) =>
                        t.deckId.equals(deck.id) & t.deletedAtMs.isNull(),
                  )
                  ..orderBy(<OrderingTerm Function(Cards)>[
                    (Cards t) => OrderingTerm.asc(t.position),
                    (Cards t) => OrderingTerm.asc(t.createdAtMs),
                  ]))
                .get();
        for (final CardRecord card in sourceCards) {
          final String newCardId = _uuid.v4();
          final CardRecord copied = CardRecord(
            id: newCardId,
            deckId: record.id,
            kind: card.kind,
            front: card.cardFront,
            back: card.back,
            hint: card.hint,
            notes: card.notes,
            tagsJson: card.tagsJson,
            position: card.position,
            createdAtMs: now,
            updatedAtMs: now,
            deletedAtMs: null,
            isDirty: true,
          );
          await _db
              .into(_db.cards)
              .insert(
                CardsCompanion(
                  id: Value<String>(newCardId),
                  deckId: Value<String>(record.id),
                  kind: Value<CardKind>(card.kind),
                  front: Value<String>(card.cardFront),
                  back: Value<String>(card.back),
                  hint: Value<String>(card.hint),
                  notes: Value<String>(card.notes),
                  tagsJson: Value<String>(card.tagsJson),
                  position: Value<int>(card.position),
                  createdAtMs: Value<int>(now),
                  updatedAtMs: Value<int>(now),
                  deletedAtMs: const Value<int?>(null),
                  isDirty: const Value<bool>(true),
                ),
              );
          await _enqueue('card', newCardId, 'create', _cardPayload(copied));

          if (includeProgress) {
            final CardStateRecord? state =
                await (_db.select(_db.cardStates)
                      ..where((CardStates t) => t.cardId.equals(card.id)))
                    .getSingleOrNull();
            if (state != null) {
              await _db
                  .into(_db.cardStates)
                  .insert(
                    CardStatesCompanion(
                      cardId: Value<String>(newCardId),
                      state: Value<FsrsState>(state.state),
                      dueAtMs: Value<int>(state.dueAtMs),
                      stability: Value<double?>(state.stability),
                      difficulty: Value<double?>(state.difficulty),
                      elapsedDays: Value<int>(state.elapsedDays),
                      scheduledDays: Value<int>(state.scheduledDays),
                      learningStep: Value<int>(state.learningStep),
                      reps: Value<int>(state.reps),
                      lapses: Value<int>(state.lapses),
                      lastReviewMs: Value<int?>(state.lastReviewMs),
                      isSuspended: Value<bool>(state.isSuspended),
                      isBuried: Value<bool>(state.isBuried),
                      updatedAtMs: Value<int>(now),
                      isDirty: const Value<bool>(true),
                    ),
                  );
              await _enqueue(
                'card_state',
                newCardId,
                'upsert',
                _statePayloadFromRecord(state, newCardId),
              );
            }
          }
        }
      }
      return newRootId;
    });
  }

  Future<FsrsReviewResult> reviewCard(
    String cardId,
    FsrsRating rating, {
    DateTime? reviewedAt,
    int? elapsedMs,
  }) async {
    return _db.transaction(() async {
      final CardRecord? card = await _getCardRow(cardId);
      if (card == null) {
        throw const ContentFailure('البطاقة غير موجودة.');
      }
      final DateTime at = (reviewedAt ?? DateTime.now()).toUtc();
      final CardStateRecord? existing = await (_db.select(
        _db.cardStates,
      )..where((CardStates t) => t.cardId.equals(cardId))).getSingleOrNull();
      final FsrsCard previous = existing == null
          ? FsrsCard.newCard(at)
          : _fsrsFromState(existing);
      final FsrsReviewResult result = _scheduler.review(
        previous,
        rating,
        at,
        elapsedMs: elapsedMs,
      );
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final CardStatesCompanion stateCompanion = CardStatesCompanion(
        cardId: Value<String>(cardId),
        state: Value<FsrsState>(result.card.state),
        dueAtMs: Value<int>(result.card.due.millisecondsSinceEpoch),
        stability: Value<double?>(result.card.stability),
        difficulty: Value<double?>(result.card.difficulty),
        elapsedDays: Value<int>(result.card.elapsedDays),
        scheduledDays: Value<int>(result.card.scheduledDays),
        learningStep: Value<int>(result.card.learningStep),
        reps: Value<int>(result.card.reps),
        lapses: Value<int>(result.card.lapses),
        lastReviewMs: Value<int?>(
          result.card.lastReview?.millisecondsSinceEpoch,
        ),
        isSuspended: Value<bool>(existing?.isSuspended ?? false),
        isBuried: Value<bool>(existing?.isBuried ?? false),
        updatedAtMs: Value<int>(now),
        isDirty: const Value<bool>(true),
      );
      if (existing == null) {
        await _db.into(_db.cardStates).insert(stateCompanion);
      } else {
        await (_db.update(_db.cardStates)
              ..where((CardStates t) => t.cardId.equals(cardId)))
            .write(stateCompanion);
      }

      final String logId = _uuid.v4();
      await _db
          .into(_db.reviewLogs)
          .insert(
            ReviewLogsCompanion(
              id: Value<String>(logId),
              cardId: Value<String>(cardId),
              rating: Value<int>(rating.value),
              reviewedAtMs: Value<int>(at.millisecondsSinceEpoch),
              elapsedMs: Value<int?>(elapsedMs),
              scheduledDays: Value<int>(result.card.scheduledDays),
              stability: Value<double?>(result.card.stability),
              difficulty: Value<double?>(result.card.difficulty),
              previousState: Value<String>(previous.state.name),
              nextState: Value<String>(result.card.state.name),
              isDirty: const Value<bool>(true),
            ),
          );

      await _enqueue(
        'card_state',
        cardId,
        'upsert',
        _statePayload(cardId, result.card, existing),
      );
      await _enqueue('review_log', logId, 'create', <String, Object?>{
        'client_id': logId,
        'card_id': cardId,
        'rating': rating.value,
        'reviewed_at': at.toIso8601String(),
        'elapsed_ms': elapsedMs,
        'scheduled_days': result.card.scheduledDays,
        'stability': result.card.stability,
        'difficulty': result.card.difficulty,
        'previous_state': previous.state.name,
        'next_state': result.card.state.name,
      });
      return result;
    });
  }

  Future<void> setCardSuspended(String cardId, bool suspended) async {
    await _setCardFlag(cardId, suspended: suspended);
  }

  Future<void> setCardBuried(String cardId, bool buried) async {
    await _setCardFlag(cardId, buried: buried);
  }

  Future<void> resetCardProgress(String cardId) async {
    await _db.transaction(() async {
      final CardRecord? card = await _getCardRow(cardId);
      if (card == null) {
        throw const ContentFailure('البطاقة غير موجودة.');
      }
      await (_db.delete(
        _db.cardStates,
      )..where((CardStates t) => t.cardId.equals(cardId))).go();
      await _enqueue('card_state', cardId, 'delete', <String, Object?>{
        'card_id': cardId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<int> pendingOutboxCount() async {
    final List<OutboxRecord> rows = await _db.select(_db.syncOutbox).get();
    return rows.length;
  }

  Future<void> _setCardFlag(
    String cardId, {
    bool? suspended,
    bool? buried,
  }) async {
    await _db.transaction(() async {
      final CardRecord? card = await _getCardRow(cardId);
      if (card == null) {
        throw const ContentFailure('البطاقة غير موجودة.');
      }
      final CardStateRecord? existing = await (_db.select(
        _db.cardStates,
      )..where((CardStates t) => t.cardId.equals(cardId))).getSingleOrNull();
      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      if (existing == null) {
        final FsrsCard fresh = FsrsCard.newCard(DateTime.now().toUtc());
        await _db
            .into(_db.cardStates)
            .insert(
              CardStatesCompanion(
                cardId: Value<String>(cardId),
                state: Value<FsrsState>(FsrsState.newCard),
                dueAtMs: Value<int>(fresh.due.millisecondsSinceEpoch),
                stability: const Value<double?>(null),
                difficulty: const Value<double?>(null),
                elapsedDays: const Value<int>(0),
                scheduledDays: const Value<int>(0),
                learningStep: const Value<int>(0),
                reps: const Value<int>(0),
                lapses: const Value<int>(0),
                lastReviewMs: const Value<int?>(null),
                isSuspended: Value<bool>(suspended ?? false),
                isBuried: Value<bool>(buried ?? false),
                updatedAtMs: Value<int>(now),
                isDirty: const Value<bool>(true),
              ),
            );
      } else {
        await (_db.update(
          _db.cardStates,
        )..where((CardStates t) => t.cardId.equals(cardId))).write(
          CardStatesCompanion(
            isSuspended: suspended == null
                ? const Value<bool>.absent()
                : Value<bool>(suspended),
            isBuried: buried == null
                ? const Value<bool>.absent()
                : Value<bool>(buried),
            updatedAtMs: Value<int>(now),
            isDirty: const Value<bool>(true),
          ),
        );
      }
      final CardStateRecord? updated = await (_db.select(
        _db.cardStates,
      )..where((CardStates t) => t.cardId.equals(cardId))).getSingleOrNull();
      if (updated != null) {
        await _enqueue(
          'card_state',
          cardId,
          'upsert',
          _statePayloadFromRecord(updated, cardId),
        );
      }
    });
  }

  Future<void> _setPrivacySubtree(
    String rootId,
    DeckPrivacy privacy,
    int now, {
    bool includeSelf = true,
  }) async {
    final List<DeckRecord> allDecks = await (_db.select(
      _db.decks,
    )..where((Decks t) => t.deletedAtMs.isNull())).get();
    final Set<String> ids = <String>{rootId};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final DeckRecord row in allDecks) {
        if (row.parentId != null &&
            ids.contains(row.parentId) &&
            !ids.contains(row.id)) {
          ids.add(row.id);
          changed = true;
        }
      }
    }
    if (!includeSelf) {
      ids.remove(rootId);
    }
    for (final String deckId in ids) {
      await (_db.update(
        _db.decks,
      )..where((Decks t) => t.id.equals(deckId))).write(
        DecksCompanion(
          privacy: Value<DeckPrivacy>(privacy),
          publishedAtMs: Value<int?>(
            privacy == DeckPrivacy.public ? now : null,
          ),
          updatedAtMs: Value<int>(now),
          isDirty: const Value<bool>(true),
        ),
      );
      final DeckRecord? updated = await (_getDeckRow(deckId));
      if (updated != null) {
        await _enqueue('deck', deckId, 'update', _deckPayload(updated));
      }
    }
  }

  Future<DeckRecord?> _getDeckRow(String id) async {
    return (_db.select(_db.decks)
          ..where((Decks t) => t.id.equals(id) & t.deletedAtMs.isNull()))
        .getSingleOrNull();
  }

  Future<CardRecord?> _getCardRow(String id) async {
    return (_db.select(_db.cards)
          ..where((Cards t) => t.id.equals(id) & t.deletedAtMs.isNull()))
        .getSingleOrNull();
  }

  Future<int> _nextDeckPosition(String? parentId) async {
    final List<DeckRecord> rows =
        await (_db.select(_db.decks)..where(
              (Decks t) =>
                  t.deletedAtMs.isNull() &
                  (parentId == null
                      ? t.parentId.isNull()
                      : t.parentId.equals(parentId)),
            ))
            .get();
    int max = -1;
    for (final DeckRecord row in rows) {
      if (row.position > max) {
        max = row.position;
      }
    }
    return max + 1;
  }

  Future<int> _nextCardPosition(String deckId) async {
    final List<CardRecord> rows =
        await (_db.select(_db.cards)..where(
              (Cards t) => t.deckId.equals(deckId) & t.deletedAtMs.isNull(),
            ))
            .get();
    int max = -1;
    for (final CardRecord row in rows) {
      if (row.position > max) {
        max = row.position;
      }
    }
    return max + 1;
  }

  void _aggregate(
    _DeckBuilder builder,
    Map<String, List<CardSummary>> cardsByDeck,
    DateTime now,
  ) {
    int directCardCount = 0;
    int newCount = 0;
    int learningCount = 0;
    int reviewStateCount = 0;
    int dueReviewCount = 0;
    int masteredCount = 0;
    int suspendedCount = 0;
    int retentionSample = 0;
    double retentionSum = 0;

    for (final CardSummary card
        in cardsByDeck[builder.record.id] ?? const <CardSummary>[]) {
      directCardCount += 1;
      if (card.isSuspended || card.isBuried) {
        suspendedCount += 1;
        continue;
      }
      final FsrsCard fsrs = card.fsrs;
      final bool isNew = fsrs.state == FsrsState.newCard || fsrs.reps == 0;
      if (isNew) {
        newCount += 1;
      } else if (fsrs.state == FsrsState.learning ||
          fsrs.state == FsrsState.relearning) {
        learningCount += 1;
      } else if (fsrs.state == FsrsState.review) {
        reviewStateCount += 1;
      }
      if (!isNew && !fsrs.due.isAfter(now)) {
        dueReviewCount += 1;
      }
      if (fsrs.state == FsrsState.review && (fsrs.stability ?? 0) >= 21) {
        masteredCount += 1;
      }
      if (fsrs.reps > 0 && fsrs.stability != null) {
        retentionSum += _scheduler.retrievability(fsrs, now);
        retentionSample += 1;
      }
    }

    int cardCount = directCardCount;
    int descendantDeckCount = 0;
    for (final _DeckBuilder child in builder.children) {
      _aggregate(child, cardsByDeck, now);
      final _Aggregate childAggregate = child.aggregate!;
      cardCount += childAggregate.cardCount;
      newCount += childAggregate.newCount;
      learningCount += childAggregate.learningCount;
      reviewStateCount += childAggregate.reviewStateCount;
      dueReviewCount += childAggregate.dueReviewCount;
      masteredCount += childAggregate.masteredCount;
      suspendedCount += childAggregate.suspendedCount;
      retentionSample += childAggregate.retentionSample;
      retentionSum += childAggregate.retentionSum;
      descendantDeckCount += 1 + childAggregate.descendantDeckCount;
    }

    builder.aggregate = _Aggregate(
      directCardCount: directCardCount,
      cardCount: cardCount,
      newCount: newCount,
      learningCount: learningCount,
      reviewStateCount: reviewStateCount,
      dueReviewCount: dueReviewCount,
      dueCount: newCount + dueReviewCount,
      masteredCount: masteredCount,
      suspendedCount: suspendedCount,
      retentionSample: retentionSample,
      retentionSum: retentionSum,
      descendantDeckCount: descendantDeckCount,
    );
  }

  DeckSummary _summaryFor(
    _DeckBuilder builder,
    Map<String, List<CardSummary>> cardsByDeck,
  ) {
    final DeckRecord record = builder.record;
    final _Aggregate aggregate = builder.aggregate!;
    return DeckSummary(
      id: record.id,
      parentId: record.parentId,
      title: record.title,
      description: record.description,
      colorHex: record.colorHex,
      iconKey: record.iconKey,
      privacy: record.privacy,
      tags: _decodeTags(record.tagsJson),
      isStarter: record.isStarter,
      isArchived: record.isArchived,
      position: record.position,
      depth: record.depth,
      createdAt: _date(record.createdAtMs),
      updatedAt: _date(record.updatedAtMs),
      publishedAt: record.publishedAtMs == null
          ? null
          : _date(record.publishedAtMs!),
      sourceTemplateId: record.sourceTemplateId,
      directCardCount: aggregate.directCardCount,
      cardCount: aggregate.cardCount,
      subdeckCount: builder.children.length,
      descendantDeckCount: aggregate.descendantDeckCount,
      newCount: aggregate.newCount,
      learningCount: aggregate.learningCount,
      reviewStateCount: aggregate.reviewStateCount,
      dueReviewCount: aggregate.dueReviewCount,
      dueCount: aggregate.dueCount,
      masteredCount: aggregate.masteredCount,
      suspendedCount: aggregate.suspendedCount,
      retention: aggregate.retention,
      retentionSample: aggregate.retentionSample,
    );
  }

  void _sortBuilders(List<_DeckBuilder> builders) {
    builders.sort((_DeckBuilder a, _DeckBuilder b) {
      final int byPosition = a.record.position.compareTo(b.record.position);
      if (byPosition != 0) {
        return byPosition;
      }
      return a.record.title.compareTo(b.record.title);
    });
    for (final _DeckBuilder builder in builders) {
      _sortBuilders(builder.children);
    }
  }

  Future<void> _enqueue(
    String entityType,
    String entityId,
    String operation,
    Map<String, Object?> payload,
  ) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion(
            id: Value<String>(_uuid.v4()),
            entityType: Value<String>(entityType),
            entityId: Value<String>(entityId),
            operation: Value<String>(operation),
            payload: Value<String>(jsonEncode(payload)),
            attempts: const Value<int>(0),
            lastError: const Value<String?>(null),
            createdAtMs: Value<int>(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
  }

  Map<String, Object?> _deckPayload(DeckRecord record, {int? deletedAtMs}) {
    return <String, Object?>{
      'id': record.id,
      'parent_id': record.parentId,
      'title': record.title,
      'description': record.description,
      'color_hex': record.colorHex,
      'icon': record.iconKey,
      'privacy': record.privacy.name,
      'tags': _decodeTags(record.tagsJson),
      'is_starter': record.isStarter,
      'is_archived': record.isArchived,
      'position': record.position,
      'depth': record.depth,
      'source_template_id': record.sourceTemplateId,
      'created_at': _date(record.createdAtMs).toIso8601String(),
      'updated_at': _date(record.updatedAtMs).toIso8601String(),
      'published_at': record.publishedAtMs == null
          ? null
          : _date(record.publishedAtMs!).toIso8601String(),
      'deleted_at': deletedAtMs == null
          ? null
          : _date(deletedAtMs).toIso8601String(),
    };
  }

  Map<String, Object?> _cardPayload(CardRecord record, {int? deletedAtMs}) {
    return <String, Object?>{
      'id': record.id,
      'deck_id': record.deckId,
      'kind': record.kind.name,
      'front': record.cardFront,
      'back': record.back,
      'hint': record.hint,
      'notes': record.notes,
      'tags': _decodeTags(record.tagsJson),
      'position': record.position,
      'created_at': _date(record.createdAtMs).toIso8601String(),
      'updated_at': _date(record.updatedAtMs).toIso8601String(),
      'deleted_at': deletedAtMs == null
          ? null
          : _date(deletedAtMs).toIso8601String(),
    };
  }

  Map<String, Object?> _statePayload(
    String cardId,
    FsrsCard card,
    CardStateRecord? previous,
  ) {
    return <String, Object?>{
      'card_id': cardId,
      'state': card.state.name,
      'due_at': card.due.toIso8601String(),
      'stability': card.stability,
      'difficulty': card.difficulty,
      'elapsed_days': card.elapsedDays,
      'scheduled_days': card.scheduledDays,
      'learning_step': card.learningStep,
      'reps': card.reps,
      'lapses': card.lapses,
      'last_review': card.lastReview?.toIso8601String(),
      'is_suspended': previous?.isSuspended ?? false,
      'is_buried': previous?.isBuried ?? false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _statePayloadFromRecord(
    CardStateRecord record,
    String cardId,
  ) {
    return <String, Object?>{
      'card_id': cardId,
      'state': record.state.name,
      'due_at': _date(record.dueAtMs).toIso8601String(),
      'stability': record.stability,
      'difficulty': record.difficulty,
      'elapsed_days': record.elapsedDays,
      'scheduled_days': record.scheduledDays,
      'learning_step': record.learningStep,
      'reps': record.reps,
      'lapses': record.lapses,
      'last_review': record.lastReviewMs == null
          ? null
          : _date(record.lastReviewMs!).toIso8601String(),
      'is_suspended': record.isSuspended,
      'is_buried': record.isBuried,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  FsrsCard _fsrsFromState(CardStateRecord record) {
    return FsrsCard(
      state: record.state,
      due: _date(record.dueAtMs),
      stability: record.stability,
      difficulty: record.difficulty,
      elapsedDays: record.elapsedDays,
      scheduledDays: record.scheduledDays,
      learningStep: record.learningStep,
      reps: record.reps,
      lapses: record.lapses,
      lastReview: record.lastReviewMs == null
          ? null
          : _date(record.lastReviewMs!),
    );
  }

  static DateTime _date(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static List<String> _decodeTags(String json) {
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((String tag) => tag.trim())
            .where((String tag) => tag.isNotEmpty)
            .toList(growable: false);
      }
    } on FormatException {
      return const <String>[];
    }
    return const <String>[];
  }

  static String _encodeTags(List<String> tags) {
    final List<String> clean = tags
        .map((String tag) => tag.trim())
        .where((String tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return jsonEncode(clean);
  }
}

class _DeckBuilder {
  _DeckBuilder(this.record);

  final DeckRecord record;
  final List<_DeckBuilder> children = <_DeckBuilder>[];
  _Aggregate? aggregate;
}

class _Aggregate {
  const _Aggregate({
    required this.directCardCount,
    required this.cardCount,
    required this.newCount,
    required this.learningCount,
    required this.reviewStateCount,
    required this.dueReviewCount,
    required this.dueCount,
    required this.masteredCount,
    required this.suspendedCount,
    required this.retentionSample,
    required this.retentionSum,
    required this.descendantDeckCount,
  });

  final int directCardCount;
  final int cardCount;
  final int newCount;
  final int learningCount;
  final int reviewStateCount;
  final int dueReviewCount;
  final int dueCount;
  final int masteredCount;
  final int suspendedCount;
  final int retentionSample;
  final double retentionSum;
  final int descendantDeckCount;

  double get retention =>
      retentionSample == 0 ? 0 : (retentionSum / retentionSample) * 100;
}
