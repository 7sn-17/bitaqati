import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../domain/gamification.dart';
import '../domain/models.dart';
import 'content_repository.dart';
import 'local/database_provider.dart';

final Provider<ContentRepository> contentRepositoryProvider =
    Provider<ContentRepository>(
      (Ref ref) => ContentRepository(ref.watch(appDatabaseProvider)),
    );

/// Every deck as a flat list. Emits again whenever the database changes.
final StreamProvider<List<DeckNode>> deckListProvider =
    StreamProvider<List<DeckNode>>(
      (Ref ref) => ref.watch(contentRepositoryProvider).watchDecks(),
    );

/// Every deck as a flat list, read synchronously. Use this in widgets that
/// already show their own loading state.
final Provider<List<DeckNode>> allDecksProvider = Provider<List<DeckNode>>(
  (Ref ref) => ref.watch(deckListProvider).valueOrNull ?? const <DeckNode>[],
);

/// One deck by id, or null when it does not exist.
final ProviderFamily<DeckNode?, String> deckByIdProvider =
    Provider.family<DeckNode?, String>(
      (Ref ref, String id) => findDeckNode(ref.watch(allDecksProvider), id),
    );

/// Cards that sit directly in a deck.
final StreamProviderFamily<List<ReviewCard>, String> deckCardsProvider =
    StreamProvider.family<List<ReviewCard>, String>(
      (Ref ref, String deckId) =>
          ref.watch(contentRepositoryProvider).watchCards(deckId),
    );

/// Which queue a review session wants.
///
/// [all] builds a "review everything" session that also pulls in cards
/// scheduled for later, which is what the empty state offers once the day's
/// work is done. A record is used as the family key because records compare by
/// value, so Riverpod caches the two queues separately.
typedef StudyQuery = ({String deckId, bool all});

/// The cards a review session should show. Loaded once per session.
final AutoDisposeFutureProviderFamily<List<ReviewCard>, StudyQuery>
studyQueueProvider = FutureProvider.autoDispose
    .family<List<ReviewCard>, StudyQuery>(
      (Ref ref, StudyQuery query) => ref
          .watch(contentRepositoryProvider)
          .studyQueue(
            query.deckId,
            newLimit: ref.watch(dailyNewLimitProvider),
            reviewLimit: ref.watch(dailyReviewLimitProvider),
            includeFuture: query.all,
          ),
    );

final AutoDisposeFutureProviderFamily<List<ReviewCard>, String>
searchCardsProvider = FutureProvider.autoDispose
    .family<List<ReviewCard>, String>(
      (Ref ref, String query) =>
          ref.watch(contentRepositoryProvider).searchCards(query),
    );

/// Tags used by any deck, most common first. Drives the filter chips.
final Provider<List<String>> deckTagsProvider = Provider<List<String>>((
  Ref ref,
) {
  final List<DeckNode> flat =
      ref.watch(deckListProvider).valueOrNull ?? const <DeckNode>[];
  final Map<String, int> counts = <String, int>{};
  for (final DeckNode deck in flat) {
    for (final String tag in deck.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final List<String> tags = counts.keys.toList();
  tags.sort((String a, String b) {
    final int byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    return byCount != 0 ? byCount : a.compareTo(b);
  });
  return tags;
});

/// Cards waiting today across every deck.
final Provider<DueTotals> dueTotalsProvider = Provider<DueTotals>((Ref ref) {
  int fresh = 0;
  int learning = 0;
  int review = 0;
  for (final DeckNode deck in ref.watch(allDecksProvider)) {
    fresh += deck.dueNew;
    learning += deck.dueLearning;
    review += deck.dueReview;
  }
  return DueTotals(fresh: fresh, learning: learning, review: review);
});

final Provider<int> totalDueProvider = Provider<int>(
  (Ref ref) => ref.watch(dueTotalsProvider).total,
);

/// The deck with the most cards due, or null when nothing is due.
final Provider<DeckNode?> todayReviewDeckProvider = Provider<DeckNode?>((
  Ref ref,
) {
  DeckNode? best;
  for (final DeckNode deck in ref.watch(allDecksProvider)) {
    if (deck.dueCount > 0 && (best == null || deck.dueCount > best.dueCount)) {
      best = deck;
    }
  }
  return best;
});

/// Consecutive days with at least one answer.
final StreamProvider<int> streakProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(contentRepositoryProvider).watchStreak(),
);

/// Real review history grouped by day. Drives the heatmap and retention.
final StreamProvider<List<ReviewActivityDay>> reviewActivityProvider =
    StreamProvider<List<ReviewActivityDay>>(
      (Ref ref) => ref.watch(contentRepositoryProvider).watchReviewActivity(),
    );

/// The gamified view of the local database: XP, level, streaks and the
/// per-day counts behind the calendar and the heatmap.
///
/// Every number is derived from [reviewActivityProvider] and the deck list, so
/// there is no separate XP table to fall out of sync with the history.
final Provider<ProgressSummary> progressSummaryProvider =
    Provider<ProgressSummary>((Ref ref) {
      final List<ReviewActivityDay> activity =
          ref.watch(reviewActivityProvider).valueOrNull ??
          const <ReviewActivityDay>[];
      final List<DeckNode> decks = ref.watch(allDecksProvider);
      int cards = 0;
      for (final DeckNode deck in decks) {
        cards += deck.cardCount;
      }
      return ProgressSummary.fromActivity(
        activity: activity,
        deckCount: decks.length,
        cardCount: cards,
        now: DateTime.now(),
      );
    });

/// Real due counts for the next seven days.
final StreamProvider<List<DueForecastDay>> dueForecastProvider =
    StreamProvider<List<DueForecastDay>>(
      (Ref ref) => ref.watch(contentRepositoryProvider).watchDueForecast(),
    );

/// Total, new, learning, due, mature and retention values for one deck.
final StreamProviderFamily<DeckStatistics, String> deckStatisticsProvider =
    StreamProvider.family<DeckStatistics, String>(
      (Ref ref, String deckId) =>
          ref.watch(contentRepositoryProvider).watchDeckStatistics(deckId),
    );

/// Remote library deck ids that already exist in the local database.
final Provider<Set<String>> installedLibraryDeckIdsProvider =
    Provider<Set<String>>((Ref ref) {
      final List<DeckNode> decks =
          ref.watch(deckListProvider).valueOrNull ?? const <DeckNode>[];
      return <String>{
        for (final DeckNode deck in decks)
          if (deck.sourceDeckId != null) deck.sourceDeckId!,
      };
    });

/// Local deck created from a remote source, if it has been installed.
final ProviderFamily<String?, String> localDeckIdForSourceProvider =
    Provider.family<String?, String>((Ref ref, String sourceId) {
      final List<DeckNode> decks =
          ref.watch(deckListProvider).valueOrNull ?? const <DeckNode>[];
      for (final DeckNode deck in decks) {
        if (deck.sourceDeckId == sourceId) {
          return deck.id;
        }
      }
      return null;
    });
