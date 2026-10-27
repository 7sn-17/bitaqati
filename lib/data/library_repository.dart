import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../domain/enums.dart';
import '../domain/models.dart';

/// A library problem whose message is safe to show to the user.
class LibraryFailure implements Exception {
  const LibraryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the public catalog, resolves share codes, and loads deck snapshots.
///
/// The catalog uses the `public_decks` projection. Share codes and direct
/// links read the `decks` and `cards` tables so an unlisted deck works
/// without ever appearing in the library.
class LibraryRepository {
  bool get isAvailable {
    if (!AppConfig.hasSupabase) {
      return false;
    }
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Every published deck, newest first.
  Future<List<DeckNode>> fetchCatalog({String query = ''}) async {
    _ensureAvailable();
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('public_decks')
          .select(
            'id,title,description,color_hex,icon,tags,settings,author_name,'
            'rating,rating_count,card_count,published_at,source_deck_id,'
            'install_count,created_at',
          )
          .order('created_at', ascending: false)
          .limit(120);
      final String needle = query.trim().toLowerCase();
      final List<DeckNode> decks = <DeckNode>[
        for (final Map<String, dynamic> row in rows) _catalogDeck(row),
      ];
      if (needle.isEmpty) {
        return decks;
      }
      return <DeckNode>[
        for (final DeckNode deck in decks)
          if (deck.title.toLowerCase().contains(needle) ||
              deck.description.toLowerCase().contains(needle) ||
              deck.tags.any(
                (String tag) => tag.toLowerCase().contains(needle),
              ) ||
              (deck.author ?? '').toLowerCase().contains(needle))
            deck,
      ];
    } on PostgrestException {
      throw const LibraryFailure(
        'تعذّر تحميل المكتبة الآن. تحقّق من اتصالك وحاول مرة أخرى.',
      );
    } catch (_) {
      throw const LibraryFailure(
        'تعذّر تحميل المكتبة الآن. تحقّق من اتصالك وحاول مرة أخرى.',
      );
    }
  }

  /// Turns a share code into the deck it points at, or null when the code is
  /// unknown, expired, or belongs to a deck that is no longer shared.
  Future<DeckNode?> resolveShareCode(String code) async {
    _ensureAvailable();
    final String needle = code.trim().toUpperCase();
    if (needle.length != 6) {
      return null;
    }
    try {
      final dynamic raw = await _client
          .rpc<dynamic>(
            'resolve_share_code',
            params: <String, dynamic>{'p_code': needle},
          )
          .timeout(const Duration(seconds: 12));
      final List<Map<String, dynamic>> hits = _asRows(raw);
      if (hits.isEmpty) {
        return null;
      }
      final String? deckId = _string(hits.first['id']);
      if (deckId == null) {
        return null;
      }
      return await _deckById(deckId);
    } on LibraryFailure {
      rethrow;
    } catch (_) {
      throw const LibraryFailure(
        'تعذّر البحث عن الرمز. تحقّق من اتصالك وحاول مرة أخرى.',
      );
    }
  }

  /// Loads one deck and every card in it.
  Future<DeckBundle?> loadBundle(String deckId) async {
    _ensureAvailable();
    try {
      final Map<String, dynamic>? deckRow = await _deckRow(deckId);
      if (deckRow == null) {
        return null;
      }
      final DeckNode deck = await _deckById(deckId);
      final List<Map<String, dynamic>> cardRows = await _client
          .from('cards')
          .select(
            'id,deck_id,type,front,back,notes,hint,tags,media,occlusion,'
            'source,ai_generated,position,created_at,updated_at',
          )
          .eq('deck_id', deckId)
          .isFilter('deleted_at', null)
          .order('position');

      return DeckBundle(
        deck: deck,
        row: DeckBundleNode(
          id: deck.id,
          position: _int(deckRow['position']),
          title: deck.title,
          description: deck.description,
          colorHex: _string(deckRow['color_hex']),
          icon: deck.iconKey,
          tags: deck.tags,
          settings: _map(deckRow['settings']) ?? const <String, Object?>{},
          coverUrl: _string(deckRow['cover_url']),
          sourceDeckId: _string(deckRow['source_deck_id']),
          sourceVersion: _int(deckRow['source_version'], fallback: 1),
          publishedAt: _date(deckRow['published_at']),
          createdAt: _date(deckRow['created_at']),
          updatedAt: _date(deckRow['updated_at']),
        ),
        cards: <DeckBundleCard>[
          for (final Map<String, dynamic> row in cardRows)
            DeckBundleCard(
              id: _string(row['id']) ?? '',
              deckId: _string(row['deck_id']) ?? '',
              type: _string(row['type']) ?? 'basic',
              front: _string(row['front']) ?? '',
              back: _string(row['back']) ?? '',
              notes: _string(row['notes']) ?? '',
              hint: _string(row['hint']) ?? '',
              tags: _strings(row['tags']),
              media: _objects(row['media']),
              occlusion: _map(row['occlusion']),
              source: _string(row['source']),
              aiGenerated: row['ai_generated'] == true,
              position: _int(row['position']),
              createdAt: _date(row['created_at']),
              updatedAt: _date(row['updated_at']),
            ),
        ],
      );
    } on PostgrestException {
      throw const LibraryFailure(
        'تعذّر فتح المجموعة. قد يكون الرابط قديماً أو أُوقفت المشاركة.',
      );
    } catch (_) {
      throw const LibraryFailure(
        'تعذّر فتح المجموعة. تحقّق من اتصالك وحاول مرة أخرى.',
      );
    }
  }

  Future<Map<String, dynamic>?> _deckRow(String deckId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('decks')
        .select(
          'id,owner_id,position,title,description,color_hex,icon,cover_url,'
          'tags,settings,privacy,source_deck_id,source_version,published_at,'
          'created_at,updated_at',
        )
        .eq('id', deckId)
        .isFilter('deleted_at', null)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Reads the deck plus its author and rating summary.
  Future<DeckNode> _deckById(String deckId) async {
    final Map<String, dynamic>? row = await _deckRow(deckId);
    if (row == null) {
      throw const LibraryFailure('هذه المجموعة لم تعد متاحة.');
    }
    final String? ownerId = _string(row['owner_id']);
    String? author;
    if (ownerId != null) {
      final List<Map<String, dynamic>> profiles = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', ownerId)
          .limit(1);
      if (profiles.isNotEmpty) {
        author = _string(profiles.first['display_name']);
      }
    }

    double? averageRating;
    int ratingCount = 0;
    try {
      final List<Map<String, dynamic>> ratingRows = await _client
          .from('deck_ratings')
          .select('rating')
          .eq('deck_id', deckId);
      if (ratingRows.isNotEmpty) {
        int sum = 0;
        for (final Map<String, dynamic> rating in ratingRows) {
          sum += _int(rating['rating']);
        }
        ratingCount = ratingRows.length;
        averageRating = sum / ratingRows.length;
      }
    } catch (_) {
      // Ratings are optional; a preview must still load without them.
    }

    final List<Map<String, dynamic>> countRows = await _client
        .from('cards')
        .select('id')
        .eq('deck_id', deckId)
        .isFilter('deleted_at', null);
    final DeckPrivacy privacy = deckPrivacyFromCloud(
      _string(row['privacy']),
    );

    return DeckNode(
      id: deckId,
      title: _string(row['title']) ?? '',
      color: colorFromHex(_string(row['color_hex'])),
      position: _int(row['position']),
      description: _string(row['description']) ?? '',
      iconKey: _string(row['icon']) ?? 'layers',
      tags: _strings(row['tags']),
      privacy: privacy,
      isPublic: privacy == DeckPrivacy.public,
      publishedAt: _date(row['published_at']),
      sourceDeckId: _string(row['source_deck_id']),
      cardCount: countRows.length,
      author: author,
      rating: averageRating,
      ratingCount: ratingCount,
    );
  }

  DeckNode _catalogDeck(Map<String, dynamic> row) {
    final int cardCount = _int(row['card_count']);
    final double rating = _double(row['rating']);
    return DeckNode(
      id: _string(row['id']) ?? '',
      title: _string(row['title']) ?? '',
      color: colorFromHex(_string(row['color_hex'])),
      description: _string(row['description']) ?? '',
      iconKey: _string(row['icon']) ?? 'layers',
      tags: _strings(row['tags']),
      privacy: DeckPrivacy.public,
      isPublic: true,
      publishedAt: _date(row['published_at']),
      sourceDeckId: _string(row['source_deck_id']),
      cardCount: cardCount,
      author: _string(row['author_name']),
      rating: rating > 0 ? rating : null,
      ratingCount: _int(row['rating_count']),
      installCount: _int(row['install_count']),
    );
  }

  /// Records a library install for the "most used" sort. Failures are silent
  /// on the client because the local copy is already usable.
  Future<void> recordInstall(String deckId) async {
    if (!isAvailable) {
      return;
    }
    try {
      await _client.rpc<dynamic>(
        'record_deck_install',
        params: <String, dynamic>{'p_deck_id': deckId},
      );
    } catch (_) {
      // Usage telemetry must never block an install.
    }
  }

  /// Saves a 1-5 star rating for the signed-in user.
  Future<void> rateDeck(String deckId, int rating) async {
    _ensureAvailable();
    if (rating < 1 || rating > 5) {
      throw const LibraryFailure('اختر تقييماً من 1 إلى 5 نجوم.');
    }
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const LibraryFailure(
        'سجّل الدخول بحساب Google لتقييم المجموعات.',
      );
    }
    try {
      await _client.from('deck_ratings').upsert(<String, Object?>{
        'deck_id': deckId,
        'user_id': user.id,
        'rating': rating,
      }, onConflict: 'deck_id,user_id');
    } on PostgrestException {
      throw const LibraryFailure(
        'تعذّر حفظ التقييم. تحقّق من اتصالك وصلاحيات حسابك.',
      );
    } catch (_) {
      throw const LibraryFailure('تعذّر حفظ التقييم. حاول مرة أخرى.');
    }
  }

  /// The signed-in user's rating for a deck, or null when unrated.
  Future<int?> fetchMyRating(String deckId) async {
    if (!isAvailable) {
      return null;
    }
    final User? user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('deck_ratings')
          .select('rating')
          .eq('deck_id', deckId)
          .eq('user_id', user.id)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return _int(rows.first['rating']);
    } catch (_) {
      return null;
    }
  }

  void _ensureAvailable() {
    if (!isAvailable) {
      throw const LibraryFailure(
        'المكتبة تحتاج اتصالاً بالإنترنت وحساب Supabase مهيّأ في هذا البناء.',
      );
    }
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is List<Object?>) {
      return <Map<String, dynamic>>[
        for (final Object? row in value)
          if (row is Map<Object?, Object?>) _stringMap(row),
      ];
    }
    if (value is Map<Object?, Object?>) {
      return <Map<String, dynamic>>[_stringMap(value)];
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _stringMap(Map<Object?, Object?> value) {
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final Object? key in value.keys) {
      out[key.toString()] = value[key];
    }
    return out;
  }

  String? _string(Object? value) => value is String ? value : null;

  int _int(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  double _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<String> _strings(Object? value) {
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

  Map<String, Object?>? _map(Object? value) {
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
      return DateTime.tryParse(value);
    }
    return null;
  }
}
