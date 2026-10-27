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

/// Reads the public catalog and loads shareable deck snapshots.
///
/// The catalog uses the `public_decks` projection. Direct links use the
/// `decks` and `cards` tables so unlisted decks work without appearing in the
/// library.
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

  Future<List<DeckNode>> fetchCatalog() async {
    _ensureAvailable();
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('public_decks')
          .select(
            'id,parent_id,root_id,depth,title,description,color_hex,icon,tags,'
            'settings,author_name,rating,rating_count,card_count,'
            'subdeck_count,is_standalone,published_at,source_deck_id,'
            'install_count',
          )
          .eq('is_standalone', true)
          .order('created_at', ascending: false)
          .limit(100);
      return <DeckNode>[
        for (final Map<String, dynamic> row in rows) _catalogDeck(row),
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

  /// Loads one deck and its direct children, plus every card in them.
  Future<DeckBundle?> loadBundle(String deckId) async {
    _ensureAvailable();
    try {
      final List<Map<String, dynamic>> deckRows = await _client
          .from('decks')
          .select(
            'id,owner_id,parent_id,root_id,depth,position,title,description,'
            'color_hex,icon,cover_url,tags,settings,privacy,source_deck_id,'
            'source_version,published_at,created_at,updated_at',
          )
          .or('id.eq.$deckId,parent_id.eq.$deckId')
          .isFilter('deleted_at', null)
          .order('depth')
          .order('position');
      if (deckRows.isEmpty) {
        return null;
      }
      Map<String, dynamic>? rootRow;
      for (final Map<String, dynamic> row in deckRows) {
        if (_string(row['id']) == deckId) {
          rootRow = row;
          break;
        }
      }
      rootRow ??= deckRows.first;
      final List<String> ids = <String>[
        for (final Map<String, dynamic> row in deckRows)
          if (_string(row['id']) != null) _string(row['id'])!,
      ];
      if (ids.isEmpty) {
        return null;
      }

      final List<Map<String, dynamic>> cardRows = await _client
          .from('cards')
          .select(
            'id,deck_id,type,front,back,notes,hint,tags,media,occlusion,'
            'source,ai_generated,position,created_at,updated_at',
          )
          .inFilter('deck_id', ids)
          .isFilter('deleted_at', null)
          .order('position');

      final String? ownerId = _string(rootRow['owner_id']);
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
          for (final Map<String, dynamic> row in ratingRows) {
            sum += _int(row['rating']);
          }
          ratingCount = ratingRows.length;
          averageRating = sum / ratingRows.length;
        }
      } catch (_) {
        // Ratings are optional; a preview must still load without them.
      }

      final DeckPrivacy privacy = deckPrivacyFromCloud(
        _string(rootRow['privacy']),
      );
      final int ownCards = cardRows
          .where((Map<String, dynamic> card) => card['deck_id'] == deckId)
          .length;
      final DeckNode root = DeckNode(
        id: deckId,
        title: _string(rootRow['title']) ?? '',
        color: colorFromHex(_string(rootRow['color_hex'])),
        parentId: null,
        rootId: deckId,
        depth: _int(rootRow['depth']),
        position: _int(rootRow['position']),
        description: _string(rootRow['description']) ?? '',
        iconKey: _string(rootRow['icon']) ?? 'layers',
        tags: _strings(rootRow['tags']),
        privacy: privacy,
        isPublic: privacy == DeckPrivacy.public,
        publishedAt: _date(rootRow['published_at']),
        sourceDeckId: _string(rootRow['source_deck_id']),
        ownCardCount: ownCards,
        cardCount: cardRows.length,
        childCount: deckRows.length > 1 ? deckRows.length - 1 : 0,
        author: author,
        rating: averageRating,
        ratingCount: ratingCount,
      );

      return DeckBundle(
        root: root,
        nodes: <DeckBundleNode>[
          for (final Map<String, dynamic> row in deckRows)
            DeckBundleNode(
              id: _string(row['id']) ?? '',
              parentId: _string(row['parent_id']),
              depth: _int(row['depth']),
              position: _int(row['position']),
              title: _string(row['title']) ?? '',
              description: _string(row['description']) ?? '',
              colorHex: _string(row['color_hex']),
              icon: _string(row['icon']) ?? 'layers',
              tags: _strings(row['tags']),
              settings: _map(row['settings']) ?? const <String, Object?>{},
              coverUrl: _string(row['cover_url']),
              sourceDeckId: _string(row['source_deck_id']),
              sourceVersion: _int(row['source_version'], fallback: 1),
              publishedAt: _date(row['published_at']),
              createdAt: _date(row['created_at']),
              updatedAt: _date(row['updated_at']),
            ),
        ],
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

  DeckNode _catalogDeck(Map<String, dynamic> row) {
    final int cardCount = _int(row['card_count']);
    final double rating = _double(row['rating']);
    return DeckNode(
      id: _string(row['id']) ?? '',
      title: _string(row['title']) ?? '',
      color: colorFromHex(_string(row['color_hex'])),
      parentId: null,
      rootId: _string(row['id']),
      depth: 0,
      description: _string(row['description']) ?? '',
      iconKey: _string(row['icon']) ?? 'layers',
      tags: _strings(row['tags']),
      privacy: DeckPrivacy.public,
      isPublic: true,
      publishedAt: _date(row['published_at']),
      sourceDeckId: _string(row['source_deck_id']),
      ownCardCount: cardCount,
      cardCount: cardCount,
      childCount: _int(row['subdeck_count']),
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
