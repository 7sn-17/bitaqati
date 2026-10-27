import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/guest_guard.dart';
import '../../core/widgets/app_message.dart';
import '../../data/content_providers.dart';
import '../../data/library_providers.dart';
import '../../data/library_repository.dart';
import '../../domain/models.dart';

/// Downloads a remote deck snapshot and copies it into the local database.
///
/// Returns the new local root deck id, or null when the user cancelled or an
/// error was shown. Callers own any per-button loading state.
Future<String?> installLibraryDeck(
  BuildContext context,
  WidgetRef ref,
  DeckNode deck,
) async {
  if (!ensureSignedIn(
    context,
    ref,
    message:
        'إضافة مجموعات من المكتبة تحتاج حساباً. '
        'سجّل الدخول بحساب Google لحفظ نسختك ومزامنتها.',
  )) {
    return null;
  }
  final List<DeckNode> localDecks =
      ref.read(deckListProvider).valueOrNull ?? const <DeckNode>[];
  for (final DeckNode local in localDecks) {
    if (local.id == deck.id || local.sourceDeckId == deck.id) {
      if (context.mounted) {
        showAppMessage(
          context,
          'هذه المجموعة موجودة في مساحتك بالفعل.',
          kind: AppMessageKind.info,
        );
      }
      return local.id;
    }
  }
  try {
    final DeckBundle? bundle = await ref
        .read(libraryRepositoryProvider)
        .loadBundle(deck.id);
    if (bundle == null) {
      if (context.mounted) {
        showAppMessage(
          context,
          'لم نعثر على هذه المجموعة. قد تكون أُوقفت مشاركتها.',
          kind: AppMessageKind.error,
        );
      }
      return null;
    }
    final String localId = await ref
        .read(contentRepositoryProvider)
        .importDeckBundle(bundle);
    await ref.read(libraryRepositoryProvider).recordInstall(deck.id);
    if (context.mounted) {
      showAppMessage(context, 'تمت إضافة «${deck.title}» إلى مجموعاتك.');
    }
    return localId;
  } on LibraryFailure catch (error) {
    if (context.mounted) {
      showAppMessage(context, error.message, kind: AppMessageKind.error);
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      showAppMessage(
        context,
        'تعذّرت إضافة المجموعة. تحقّق من اتصالك وحاول مرة أخرى.',
        kind: AppMessageKind.error,
      );
    }
    return null;
  }
}
