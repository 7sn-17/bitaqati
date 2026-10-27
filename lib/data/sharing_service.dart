import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'content_repository.dart';

/// A publishing problem whose message is safe to show to the user.
class SharingFailure implements Exception {
  const SharingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What the user needs to hand a deck to someone else: the deck id and the
/// six-character code. Decks are shared by code only, so there is no link here
/// to copy, paste or accidentally send to the wrong person.
class SharingResult {
  const SharingResult({required this.deckId, required this.shareCode});

  final String deckId;
  final String shareCode;
}

/// Publishes a local deck snapshot to Supabase.
///
/// Decks are flat, so publishing is one deck row plus its cards. The local
/// UUID is kept, so the share code resolves to the same deck before and after
/// someone installs it, and re-publishing updates in place instead of creating
/// duplicates.
class SharingService {
  SharingService(this._repository);

  final ContentRepository _repository;

  Future<SharingResult> publish({
    required String deckId,
    required DeckPrivacy privacy,
  }) async {
    if (privacy == DeckPrivacy.private) {
      throw const SharingFailure('اختر «بالرمز فقط» أو «مكتبة عامة» للنشر.');
    }
    final User user = _requireUser();
    final SupabaseClient client = _client();
    try {
      final DeckBundle bundle = await _repository.exportDeckBundle(deckId);
      if (bundle.cards.isEmpty) {
        throw const SharingFailure(
          'أضف بطاقة واحدة على الأقل قبل مشاركة المجموعة.',
        );
      }

      await client
          .from('decks')
          .upsert(
            _deckPayload(
              bundle.row,
              ownerId: user.id,
              privacy: privacy,
              shareCode: bundle.deck.shareCode,
            ),
          );

      // The server owns uniqueness: it keeps our code unless another account
      // already claimed it, in which case it minted a fresh one. Read back
      // whatever it settled on so the local copy always matches.
      final List<Map<String, dynamic>> stored = await client
          .from('decks')
          .select('share_code')
          .eq('id', deckId)
          .limit(1);
      final String code = stored.isNotEmpty
          ? (stored.first['share_code'] as String? ?? '')
          : (bundle.deck.shareCode ?? '');
      if (code.isEmpty) {
        throw const SharingFailure('تعذّر توليد رمز المشاركة. حاول مرة أخرى.');
      }
      // The server owns uniqueness, so it may have replaced a colliding code.
      await _repository.setDeckShareCode(deckId, code);

      await client.from('cards').upsert(<Map<String, Object?>>[
        for (final DeckBundleCard card in bundle.cards)
          <String, Object?>{
            'id': card.id,
            'deck_id': card.deckId,
            'type': card.type,
            'front': card.front,
            'back': card.back,
            'notes': card.notes,
            'hint': card.hint,
            'tags': card.tags,
            'media': card.media,
            'occlusion': card.occlusion,
            'source': card.source,
            'ai_generated': card.aiGenerated,
            'position': card.position,
          },
      ]);

      await _repository.setDeckPrivacy(deckId, privacy);
      return SharingResult(deckId: deckId, shareCode: code);
    } on SharingFailure {
      rethrow;
    } on PostgrestException {
      throw const SharingFailure(
        'تعذّر نشر المجموعة. تحقّق من اتصالك وصلاحيات حسابك.',
      );
    } catch (_) {
      throw const SharingFailure(
        'تعذّر نشر المجموعة. تحقّق من اتصالك وحاول مرة أخرى.',
      );
    }
  }

  Future<void> unpublish(String deckId) async {
    _requireUser();
    final SupabaseClient client = _client();
    try {
      await client
          .from('decks')
          .update(<String, Object?>{'privacy': 'private'})
          .eq('id', deckId);
      await _repository.setDeckPrivacy(deckId, DeckPrivacy.private);
    } on PostgrestException {
      throw const SharingFailure(
        'تعذّر إيقاف المشاركة. تحقّق من اتصالك وصلاحيات حسابك.',
      );
    } catch (_) {
      throw const SharingFailure(
        'تعذّر إيقاف المشاركة. تحقّق من اتصالك وحاول مرة أخرى.',
      );
    }
  }

  Map<String, Object?> _deckPayload(
    DeckBundleNode node, {
    required String ownerId,
    required DeckPrivacy privacy,
    required String? shareCode,
  }) {
    return <String, Object?>{
      'id': node.id,
      'owner_id': ownerId,
      'position': node.position,
      'title': node.title,
      'description': node.description,
      'color_hex': node.colorHex,
      'icon': node.icon,
      'privacy': privacy.name,
      'cover_url': node.coverUrl,
      'tags': node.tags,
      'settings': node.settings,
      'is_starter': false,
      'share_code': shareCode,
      // Attribution: kept on the row so a remix still credits the person who
      // wrote the original, even after the original is unpublished.
      'original_deck_id': node.originalDeckId,
      'original_author_name': node.originalAuthorName,
    };
  }

  User _requireUser() {
    if (!AppConfig.hasSupabase) {
      throw const SharingFailure(
        'المشاركة تحتاج اتصالاً بالإنترنت وإعداد Supabase في هذا البناء.',
      );
    }
    final User? user = _client().auth.currentUser;
    if (user == null) {
      throw const SharingFailure(
        'سجّل الدخول بحساب Google لتتمكن من نشر المجموعات ومشاركتها.',
      );
    }
    return user;
  }

  SupabaseClient _client() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const SharingFailure(
        'خدمة المشاركة غير متاحة في هذا البناء. تحقّق من إعداد Supabase.',
      );
    }
  }
}
