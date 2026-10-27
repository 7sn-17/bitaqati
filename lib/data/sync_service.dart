import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../domain/enums.dart';
import 'local/app_database.dart';
import 'local/tables.dart';

/// What one sync pass did, for the settings screen and the status banner.
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.error,
  });

  final int pushed;
  final int pulled;
  final int failed;
  final String? error;

  bool get ok => error == null && failed == 0;

  bool get idle => pushed == 0 && pulled == 0 && failed == 0 && error == null;
}

/// Two-way sync between the local Drift database and Supabase.
///
/// The local database stays authoritative for studying: every write already
/// queues a row in `sync_queue`, so a sync is "drain the queue, then pull
/// anything newer". Conflicts resolve last-write-wins on `updated_at`, except
/// for a row that still has a pending queue entry, which always keeps the
/// local version.
class SyncService {
  SyncService(this._db);

  final AppDatabase _db;

  static const String _lastSyncKey = 'last_sync_at';

  SupabaseClient? _clientOrNull() {
    if (!AppConfig.hasSupabase) {
      return null;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Pushes local changes, then pulls the account's decks, cards and review
  /// state. Safe to call on every app start: it is a no-op when signed out.
  Future<SyncReport> run() async {
    final SupabaseClient? client = _clientOrNull();
    if (client == null) {
      return const SyncReport();
    }
    final User? user = client.auth.currentUser;
    if (user == null) {
      return const SyncReport();
    }

    int pushed = 0;
    try {
      pushed = await _push(client, user.id);
    } catch (error) {
      return SyncReport(error: _describe(error));
    }

    int pulled = 0;
    try {
      pulled = await _pull(client, user.id);
    } catch (error) {
      return SyncReport(pushed: pushed, error: _describe(error));
    }

    await _db
        .into(_db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            key: _lastSyncKey,
            value: DateTime.now().toUtc().toIso8601String(),
          ),
        );
    return SyncReport(pushed: pushed, pulled: pulled);
  }

  /// The number of writes still waiting, shown next to the sync button.
  Future<int> pendingCount() async {
    final QueryRow row = await _db
        .customSelect('SELECT COUNT(*) AS total FROM sync_queue')
        .getSingle();
    return row.read<int>('total');
  }

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  Future<int> _push(SupabaseClient client, String userId) async {
    final List<SyncQueueRow> queue = await (_db.select(
      _db.syncQueue,
    )..orderBy([(SyncQueue t) => OrderingTerm.asc(t.id)])).get();
    if (queue.isEmpty) {
      return 0;
    }

    final Map<String, List<SyncQueueRow>> byEntity =
        <String, List<SyncQueueRow>>{};
    for (final SyncQueueRow row in queue) {
      byEntity.putIfAbsent(row.entity, () => <SyncQueueRow>[]).add(row);
    }

    int pushed = 0;
    // Parents before children: decks, then cards, then the state that points
    // at a card, then the log that points at both.
    for (final String entity in <String>[
      'decks',
      'cards',
      'card_states',
      'review_logs',
    ]) {
      final List<SyncQueueRow> items =
          byEntity.remove(entity) ?? <SyncQueueRow>[];
      if (items.isEmpty) {
        continue;
      }
      try {
        await _pushEntity(client, entity, items, userId);
        await _deleteQueue(items);
        pushed += items.length;
      } catch (error) {
        await _recordFailure(items, error);
      }
    }

    // Unknown entities are dropped rather than retried forever.
    for (final List<SyncQueueRow> items in byEntity.values) {
      await _deleteQueue(items);
    }
    return pushed;
  }

  Future<void> _pushEntity(
    SupabaseClient client,
    String entity,
    List<SyncQueueRow> items,
    String userId,
  ) async {
    if (entity == 'decks') {
      await _pushDecks(client, items, userId);
    } else if (entity == 'cards') {
      await _pushCards(client, items);
    } else if (entity == 'card_states') {
      await _pushCardStates(client, items, userId);
    } else if (entity == 'review_logs') {
      await _pushReviewLogs(client, items, userId);
    }
  }

  Future<void> _pushDecks(
    SupabaseClient client,
    List<SyncQueueRow> items,
    String userId,
  ) async {
    final Set<String> ids = <String>{
      for (final SyncQueueRow row in items) row.entityId,
    };
    final Set<String> removals = <String>{
      for (final SyncQueueRow row in items)
        if (row.operation == SyncOperation.delete) row.entityId,
    };
    final List<DeckRow> rows = await (_db.select(
      _db.decks,
    )..where((Decks d) => d.id.isIn(ids))).get();

    final List<Map<String, Object?>> upserts = <Map<String, Object?>>[];
    final Set<String> pushed = <String>{};
    for (final DeckRow row in rows) {
      if (removals.contains(row.id) || row.deletedAt != null) {
        continue;
      }
      upserts.add(_deckPayload(row, userId));
      pushed.add(row.id);
    }
    if (upserts.isNotEmpty) {
      await client.from('decks').upsert(upserts);
      // The cloud owns the row now, so remember who it belongs to.
      await (_db.update(_db.decks)..where((Decks d) => d.id.isIn(pushed)))
          .write(DecksCompanion(ownerId: Value<String>(userId)));
    }
    if (removals.isNotEmpty) {
      await client
          .from('decks')
          .update(<String, Object?>{
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .inFilter('id', removals.toList());
    }
  }

  Future<void> _pushCards(
    SupabaseClient client,
    List<SyncQueueRow> items,
  ) async {
    final Set<String> ids = <String>{
      for (final SyncQueueRow row in items) row.entityId,
    };
    final Set<String> removals = <String>{
      for (final SyncQueueRow row in items)
        if (row.operation == SyncOperation.delete) row.entityId,
    };
    final List<CardRow> rows = await (_db.select(
      _db.cards,
    )..where((Cards c) => c.id.isIn(ids))).get();

    final List<Map<String, Object?>> upserts = <Map<String, Object?>>[];
    for (final CardRow row in rows) {
      if (removals.contains(row.id) || row.deletedAt != null) {
        continue;
      }
      upserts.add(_cardPayload(row));
    }
    if (upserts.isNotEmpty) {
      await client.from('cards').upsert(upserts);
    }
    if (removals.isNotEmpty) {
      await client
          .from('cards')
          .update(<String, Object?>{
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .inFilter('id', removals.toList());
    }
  }

  Future<void> _pushCardStates(
    SupabaseClient client,
    List<SyncQueueRow> items,
    String userId,
  ) async {
    final Set<String> ids = <String>{
      for (final SyncQueueRow row in items) row.entityId,
    };
    final List<CardStateRow> rows = await (_db.select(
      _db.cardStates,
    )..where((CardStates s) => s.cardId.isIn(ids))).get();
    if (rows.isEmpty) {
      return;
    }
    await client.from('card_states').upsert(
      <Map<String, Object?>>[
        for (final CardStateRow row in rows) _cardStatePayload(row, userId),
      ],
    );
  }

  Future<void> _pushReviewLogs(
    SupabaseClient client,
    List<SyncQueueRow> items,
    String userId,
  ) async {
    final Set<String> ids = <String>{
      for (final SyncQueueRow row in items) row.entityId,
    };
    final List<ReviewLogRow> rows = await (_db.select(
      _db.reviewLogs,
    )..where((ReviewLogs r) => r.id.isIn(ids))).get();
    if (rows.isEmpty) {
      return;
    }
    // client_id is unique in the cloud, so replaying a log is harmless.
    await client.from('review_logs').upsert(
      <Map<String, Object?>>[
        for (final ReviewLogRow row in rows) _reviewLogPayload(row, userId),
      ],
      onConflict: 'client_id',
    );
  }

  Map<String, Object?> _deckPayload(DeckRow row, String userId) {
    return <String, Object?>{
      'id': row.id,
      'owner_id': userId,
      'position': row.position,
      'title': row.title,
      'description': row.description,
      'color_hex': row.colorHex,
      'icon': row.icon,
      'privacy': row.privacy.name,
      'cover_url': row.coverUrl,
      'tags': row.tags,
      'settings': row.settings,
      'is_starter': row.isStarter,
      'share_code': row.shareCode,
    };
  }

  Map<String, Object?> _cardPayload(CardRow row) {
    return <String, Object?>{
      'id': row.id,
      'deck_id': row.deckId,
      'type': row.type.name,
      'front': row.front,
      'back': row.back,
      'notes': row.notes,
      'hint': row.hint,
      'tags': row.tags,
      'media': row.media,
      'occlusion': row.occlusion,
      'source': row.source,
      'ai_generated': row.aiGenerated,
      'favorite': row.favorite,
      'position': row.position,
    };
  }

  Map<String, Object?> _cardStatePayload(CardStateRow row, String userId) {
    return <String, Object?>{
      'card_id': row.cardId,
      'user_id': userId,
      'state': row.status.cloudValue,
      'due': row.due.toUtc().toIso8601String(),
      'stability': row.stability,
      'difficulty': row.difficulty,
      'elapsed_days': row.elapsedDays,
      'scheduled_days': row.scheduledDays,
      'learning_steps': row.learningSteps,
      'reps': row.reps,
      'lapses': row.lapses,
      'last_review': row.lastReview?.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _reviewLogPayload(ReviewLogRow row, String userId) {
    return <String, Object?>{
      'client_id': row.id,
      'card_id': row.cardId,
      'user_id': userId,
      'rating': row.rating,
      'reviewed_at': row.reviewedAt.toUtc().toIso8601String(),
      'elapsed_ms': row.elapsedMs,
      'scheduled_days': row.scheduledDays,
      'stability': row.stability,
      'difficulty': row.difficulty,
      'prev_state': row.prevState,
      'next_state': row.nextState,
    };
  }

  Future<void> _deleteQueue(List<SyncQueueRow> items) async {
    await (_db.delete(_db.syncQueue)..where(
          (SyncQueue q) => q.id.isIn(<int>{
            for (final SyncQueueRow row in items) row.id,
          }),
        ))
        .go();
  }

  Future<void> _recordFailure(List<SyncQueueRow> items, Object error) async {
    final String message = _describe(error);
    final Set<int> ids = <int>{
      for (final SyncQueueRow row in items) row.id,
    };
    final int attempts = items.first.attempts + 1;
    await (_db.update(
      _db.syncQueue,
    )..where((SyncQueue q) => q.id.isIn(ids))).write(
      SyncQueueCompanion(
        attempts: Value<int>(attempts),
        lastError: Value<String?>(message),
      ),
    );
    // After five failures the row will not succeed on its own (a missing
    // parent, a value the server rejects). Dropping it keeps one bad row from
    // blocking every later sync.
    if (attempts >= 5) {
      await (_db.delete(
        _db.syncQueue,
      )..where((SyncQueue q) => q.id.isIn(ids))).go();
    }
  }

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  Future<int> _pull(SupabaseClient client, String userId) async {
    final Set<String> busy = <String>{
      for (final SyncQueueRow row in await _db.select(_db.syncQueue).get())
        '${row.entity}:${row.entityId}',
    };
    int changed = 0;
    changed += await _pullDecks(client, userId, busy);
    changed += await _pullCards(client, userId, busy);
    changed += await _pullCardStates(client, userId, busy);
    return changed;
  }

  Future<int> _pullDecks(
    SupabaseClient client,
    String userId,
    Set<String> busy,
  ) async {
    final List<Map<String, dynamic>> rows = await client
        .from('decks')
        .select(
          'id,position,title,description,color_hex,icon,cover_url,tags,'
          'settings,privacy,is_starter,share_code,published_at,'
          'created_at,updated_at,deleted_at',
        )
        .eq('owner_id', userId);

    final Map<String, DeckRow> local = <String, DeckRow>{
      for (final DeckRow row in await _db.select(_db.decks).get()) row.id: row,
    };

    int changed = 0;
    for (final Map<String, dynamic> row in rows) {
      final String id = _text(row['id']) ?? '';
      if (id.isEmpty || busy.contains('decks:$id')) {
        continue;
      }
      final DateTime remoteUpdated =
          _date(row['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DeckRow? existing = local[id];
      if (existing != null && existing.updatedAt.isAfter(remoteUpdated)) {
        continue;
      }
      await _db
          .into(_db.decks)
          .insertOnConflictUpdate(
            DecksCompanion.insert(
              id: id,
              ownerId: Value<String?>(userId),
              shareCode: Value<String?>(_text(row['share_code'])),
              position: Value<int>(_number(row['position'])),
              title: _text(row['title']) ?? 'مجموعة',
              description: Value<String>(_text(row['description']) ?? ''),
              colorHex: Value<String?>(_text(row['color_hex'])),
              icon: Value<String>(_text(row['icon']) ?? 'layers'),
              privacy: Value<DeckPrivacy>(
                deckPrivacyFromCloud(_text(row['privacy'])),
              ),
              coverUrl: Value<String?>(_text(row['cover_url'])),
              tags: Value<List<String>>(_texts(row['tags'])),
              settings: Value<Map<String, Object?>>(
                _json(row['settings']) ?? const <String, Object?>{},
              ),
              isStarter: Value<bool>(row['is_starter'] == true),
              publishedAt: Value<DateTime?>(_date(row['published_at'])),
              createdAt: Value<DateTime>(
                _date(row['created_at']) ?? DateTime.now(),
              ),
              updatedAt: Value<DateTime>(remoteUpdated),
              deletedAt: Value<DateTime?>(_date(row['deleted_at'])),
            ),
          );
      changed++;
    }
    return changed;
  }

  Future<int> _pullCards(
    SupabaseClient client,
    String userId,
    Set<String> busy,
  ) async {
    final List<String> deckIds = <String>[
      for (final DeckRow row in await (_db.select(_db.decks)..where(
            (Decks d) => d.ownerId.equals(userId) & d.deletedAt.isNull(),
          ))
              .get())
        row.id,
    ];
    if (deckIds.isEmpty) {
      return 0;
    }

    final Map<String, CardRow> local = <String, CardRow>{
      for (final CardRow row in await _db.select(_db.cards).get()) row.id: row,
    };
    final Set<String> knownDecks = <String>{
      for (final DeckRow row in await _db.select(_db.decks).get()) row.id,
    };

    int changed = 0;
    for (int start = 0; start < deckIds.length; start += 40) {
      final List<String> slice = deckIds.skip(start).take(40).toList();
      final List<Map<String, dynamic>> rows = await client
          .from('cards')
          .select(
            'id,deck_id,type,front,back,notes,hint,tags,media,occlusion,'
            'source,ai_generated,favorite,position,created_at,updated_at,'
            'deleted_at',
          )
          .inFilter('deck_id', slice);

      for (final Map<String, dynamic> row in rows) {
        final String id = _text(row['id']) ?? '';
        final String deckId = _text(row['deck_id']) ?? '';
        if (id.isEmpty || deckId.isEmpty || busy.contains('cards:$id')) {
          continue;
        }
        // A card whose deck was deleted locally must not come back.
        if (!knownDecks.contains(deckId)) {
          continue;
        }
        final DateTime remoteUpdated =
            _date(row['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final CardRow? existing = local[id];
        if (existing != null && existing.updatedAt.isAfter(remoteUpdated)) {
          continue;
        }
        await _db
            .into(_db.cards)
            .insertOnConflictUpdate(
              CardsCompanion.insert(
                id: id,
                deckId: deckId,
                type: Value<CardType>(_cardType(_text(row['type']))),
                front: Value<String>(_text(row['front']) ?? ''),
                back: Value<String>(_text(row['back']) ?? ''),
                notes: Value<String>(_text(row['notes']) ?? ''),
                hint: Value<String>(_text(row['hint']) ?? ''),
                tags: Value<List<String>>(_texts(row['tags'])),
                media: Value<List<Object?>>(_objects(row['media'])),
                occlusion: Value<Map<String, Object?>?>(
                  _json(row['occlusion']),
                ),
                source: Value<String?>(_text(row['source'])),
                aiGenerated: Value<bool>(row['ai_generated'] == true),
                favorite: Value<bool>(row['favorite'] == true),
                position: Value<int>(_number(row['position'])),
                createdAt: Value<DateTime>(
                  _date(row['created_at']) ?? DateTime.now(),
                ),
                updatedAt: Value<DateTime>(remoteUpdated),
                deletedAt: Value<DateTime?>(_date(row['deleted_at'])),
              ),
            );
        changed++;
      }
    }
    return changed;
  }

  Future<int> _pullCardStates(
    SupabaseClient client,
    String userId,
    Set<String> busy,
  ) async {
    final List<Map<String, dynamic>> rows = await client
        .from('card_states')
        .select(
          'card_id,state,due,stability,difficulty,elapsed_days,'
          'scheduled_days,learning_steps,reps,lapses,last_review,updated_at',
        )
        .eq('user_id', userId);
    if (rows.isEmpty) {
      return 0;
    }

    final Map<String, CardStateRow> local = <String, CardStateRow>{
      for (final CardStateRow row in await _db.select(_db.cardStates).get())
        row.cardId: row,
    };
    final Set<String> knownCards = <String>{
      for (final CardRow row in await _db.select(_db.cards).get()) row.id,
    };

    int changed = 0;
    for (final Map<String, dynamic> row in rows) {
      final String cardId = _text(row['card_id']) ?? '';
      if (cardId.isEmpty ||
          !knownCards.contains(cardId) ||
          busy.contains('card_states:$cardId')) {
        continue;
      }
      final DateTime remoteUpdated =
          _date(row['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final CardStateRow? existing = local[cardId];
      if (existing != null && existing.updatedAt.isAfter(remoteUpdated)) {
        continue;
      }
      await _db
          .into(_db.cardStates)
          .insertOnConflictUpdate(
            CardStatesCompanion.insert(
              cardId: cardId,
              status: Value<CardStatus>(
                cardStatusFromCloud(_text(row['state']) ?? 'new'),
              ),
              due: Value<DateTime>(_date(row['due']) ?? DateTime.now()),
              stability: Value<double>(_decimal(row['stability'])),
              difficulty: Value<double>(_decimal(row['difficulty'])),
              elapsedDays: Value<int>(_number(row['elapsed_days'])),
              scheduledDays: Value<int>(_number(row['scheduled_days'])),
              learningSteps: Value<int>(_number(row['learning_steps'])),
              reps: Value<int>(_number(row['reps'])),
              lapses: Value<int>(_number(row['lapses'])),
              lastReview: Value<DateTime?>(_date(row['last_review'])),
              updatedAt: Value<DateTime>(remoteUpdated),
            ),
          );
      changed++;
    }
    return changed;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _describe(Object error) {
    if (error is PostgrestException) {
      return 'تعذّرت المزامنة: ${error.message}';
    }
    if (error is AuthException) {
      return 'تعذّرت المزامنة: انتهت صلاحية الجلسة. سجّل الدخول من جديد.';
    }
    return 'تعذّرت المزامنة. تحقّق من اتصالك وحاول مرة أخرى.';
  }

  CardType _cardType(String? value) {
    return CardType.values.firstWhere(
      (CardType type) => type.name == value,
      orElse: () => CardType.basic,
    );
  }

  String? _text(Object? value) => value is String ? value : null;

  int _number(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _decimal(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<String> _texts(Object? value) {
    if (value is List<Object?>) {
      return value.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  List<Object?> _objects(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    return const <Object?>[];
  }

  Map<String, Object?>? _json(Object? value) {
    if (value is Map<Object?, Object?>) {
      final Map<String, Object?> out = <String, Object?>{};
      for (final Object? key in value.keys) {
        out[key.toString()] = value[key];
      }
      return out;
    }
    return null;
  }

  DateTime? _date(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
