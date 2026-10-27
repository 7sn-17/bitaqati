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

/// Publishes a local deck snapshot to Supabase.
///
/// A main deck is published with its sub-decks. A sub-deck can also be
/// published on its own; it becomes a standalone shareable deck without
/// exposing its siblings or parent. The local UUID is kept, so the same link
/// can be used before and after installing.
class SharingService {
  SharingService(this._repository);

  final ContentRepository _repository;

  Future<String> publish({
    required String deckId,
    required DeckPrivacy privacy,
  }) async {
    if (privacy == DeckPrivacy.private) {
      throw const SharingFailure('اختر «رابط فقط» أو «مكتبة عامة» للنشر.');
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
      final DeckBundleNode root = bundle.nodes.firstWhere(
        (DeckBundleNode node) => node.id == deckId,
        orElse: () => bundle.nodes.first,
      );
      final List<DeckBundleNode> children = bundle.nodes
          .where((DeckBundleNode node) => node.id != deckId)
          .toList(growable: false);

      final String? localParentId = bundle.root.parentId;
      DeckPrivacy? parentPrivacy;
      if (bundle.root.depth == kSubDeckDepth && localParentId != null) {
        parentPrivacy = await _repository.deckPrivacy(localParentId);
      }
      // A sub-deck keeps its place under a published main deck. If the parent
      // is private, the sub-deck is published as a standalone shareable deck.
      final bool keepParent =
          bundle.root.depth == kSubDeckDepth &&
          localParentId != null &&
          parentPrivacy != null &&
          parentPrivacy != DeckPrivacy.private;
      final String rootId = keepParent
          ? (bundle.root.rootId ?? localParentId)
          : deckId;
      final String? rootParentId = keepParent ? localParentId : null;
      final int rootDepth = keepParent ? kSubDeckDepth : kMainDeckDepth;
      final List<String> rootPath = keepParent
          ? <String>[rootId]
          : const <String>[];

      await client
          .from('decks')
          .upsert(
            _deckPayload(
              root,
              parentId: rootParentId,
              rootId: rootId,
              depth: rootDepth,
              path: rootPath,
              position: keepParent ? root.position : 0,
              ownerId: user.id,
              privacy: privacy,
            ),
          );
      if (children.isNotEmpty) {
        await client.from('decks').upsert(
          <Map<String, Object?>>[
            for (final DeckBundleNode child in children)
              _deckPayload(
                child,
                parentId: deckId,
                rootId: deckId,
                depth: kSubDeckDepth,
                path: <String>[deckId],
                position: child.position,
                ownerId: user.id,
                privacy: privacy,
              ),
          ],
        );
      }
      if (bundle.cards.isNotEmpty) {
        await client.from('cards').upsert(
          <Map<String, Object?>>[
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
          ],
        );
      }
      await _repository.setDeckPrivacy(deckId, privacy);
      return AppConfig.deckShareLink(deckId);
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
          .or('id.eq.$deckId,root_id.eq.$deckId');
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
    required String? parentId,
    required String rootId,
    required int depth,
    required List<String> path,
    required int position,
    required String ownerId,
    required DeckPrivacy privacy,
  }) {
    return <String, Object?>{
      'id': node.id,
      'owner_id': ownerId,
      'parent_id': parentId,
      'root_id': rootId,
      'path': path,
      'depth': depth,
      'position': position,
      'title': node.title,
      'description': node.description,
      'color_hex': node.colorHex,
      'icon': node.icon,
      'privacy': privacy.name,
      'cover_url': node.coverUrl,
      'tags': node.tags,
      'settings': node.settings,
      'is_starter': false,
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
