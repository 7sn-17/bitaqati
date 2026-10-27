import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'library_repository.dart';

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>((Ref ref) => LibraryRepository());

/// Public library catalog. Refreshing the provider re-fetches it.
final FutureProvider<List<DeckNode>> libraryDecksProvider =
    FutureProvider<List<DeckNode>>(
      (Ref ref) => ref.watch(libraryRepositoryProvider).fetchCatalog(),
    );

/// One deck from a share link, including its cards, ready to install.
final FutureProviderFamily<DeckBundle?, String> libraryBundleProvider =
    FutureProvider.family<DeckBundle?, String>(
      (Ref ref, String deckId) =>
          ref.watch(libraryRepositoryProvider).loadBundle(deckId),
    );

/// The preview shown by the deck screen when the deck is not local yet.
final FutureProviderFamily<DeckNode?, String> libraryDeckProvider =
    FutureProvider.family<DeckNode?, String>((Ref ref, String deckId) async {
      final DeckBundle? bundle = await ref.watch(
        libraryBundleProvider(deckId).future,
      );
      return bundle?.deck;
    });

/// A deck found by its six-character code, ready to preview and install.
final FutureProviderFamily<DeckNode?, String> shareCodeDeckProvider =
    FutureProvider.family<DeckNode?, String>(
      (Ref ref, String code) =>
          ref.watch(libraryRepositoryProvider).resolveShareCode(code),
    );

/// The signed-in user's 1-5 star rating for a public deck.
final FutureProviderFamily<int?, String> myDeckRatingProvider =
    FutureProvider.family<int?, String>(
      (Ref ref, String deckId) =>
          ref.watch(libraryRepositoryProvider).fetchMyRating(deckId),
    );
