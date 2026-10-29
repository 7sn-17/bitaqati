import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../domain/gamification.dart';
import '../domain/models.dart';
import 'content_repository.dart';
import 'local/database_provider.dart';
import 'pro_providers.dart';

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
///
/// This is also where the free tier's freeze is applied, so nothing downstream
/// has to remember it: a deck past the allowance arrives with [DeckNode.frozen]
/// set, and every list, card and route already carries that flag.
///
/// The newest decks stay open. Someone who lapsed keeps studying what they were
/// working on and only the shelf gathers dust, which is the opposite of
/// deleting their oldest work.
final Provider<List<DeckNode>> allDecksProvider = Provider<List<DeckNode>>((
  Ref ref,
) {
  final List<DeckNode> decks =
      ref.watch(deckListProvider).valueOrNull ?? const <DeckNode>[];
  // The allowance is a share of the library, so it has to be read from the
  // library itself: half of these decks stay open, newest first.
  final int? limit = ref.watch(proNowProvider).deckLimitFor(decks.length);
  if (limit == null || decks.length <= limit) {
    return decks;
  }
  final List<DeckNode> newest = <DeckNode>[...decks]
    ..sort((DeckNode a, DeckNode b) => b.position.compareTo(a.position));
  final Set<String> open = newest
      .take(limit)
      .map((DeckNode deck) => deck.id)
      .toSet();
  return <DeckNode>[
    for (final DeckNode deck in decks)
      open.contains(deck.id) ? deck : deck.copyWith(frozen: true),
  ];
});

/// Null when unlimited, otherwise how many more decks may be created.
final Provider<int?> decksLeftProvider = Provider<int?>((Ref ref) {
  final int used = ref.watch(deckListProvider).valueOrNull?.length ?? 0;
  final int? limit = ref.watch(proNowProvider).deckLimitFor(used);
  if (limit == null) {
    return null;
  }
  final int left = limit - used;
  return left < 0 ? 0 : left;
});

/// Ids of the decks the free tier has frozen.
///
/// A frozen deck is not deleted and not hidden: it keeps its cards, its
/// history and its place in the list, and it can be studied again the moment
/// the subscription comes back. What it cannot do is hand out cards today, so
/// every queue that spans the whole library subtracts this set.
final Provider<Set<String>> frozenDeckIdsProvider = Provider<Set<String>>((
  Ref ref,
) {
  return <String>{
    for (final DeckNode deck in ref.watch(allDecksProvider))
      if (deck.frozen) deck.id,
  };
});

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

/// The scope id that means "every deck".
///
/// Routes carry a deck id, so the global session needs an id of its own rather
/// than a second route shape. Deck ids are UUIDs, so this can never collide
/// with a real one.
const String kAllDecksScope = 'all';

/// True when [scope] asks for the whole library instead of one deck.
bool isAllDecksScope(String scope) => scope == kAllDecksScope;

/// Cards for a study mode, scoped to one deck or to everything.
///
/// The study screens take a scope id, not a deck, so "review all due cards"
/// runs through exactly the same code as "review this deck".
/// Auto-disposed on purpose: a study screen is the only reader, and a session
/// that has ended should not leave a query over every card of the deck running
/// for the rest of the app's life.
final AutoDisposeStreamProviderFamily<List<ReviewCard>, String>
studyCardsProvider = StreamProvider.autoDispose
    .family<List<ReviewCard>, String>((Ref ref, String scope) {
      final ContentRepository repository = ref.watch(contentRepositoryProvider);
      if (!isAllDecksScope(scope)) {
        return repository.watchCards(scope);
      }
      final Set<String> frozen = ref.watch(frozenDeckIdsProvider);
      if (frozen.isEmpty) {
        return repository.watchAllCards();
      }
      return repository.watchAllCards().map(
        (List<ReviewCard> cards) => <ReviewCard>[
          for (final ReviewCard card in cards)
            if (!frozen.contains(card.deckId)) card,
        ],
      );
    });

/// Which queue a review session wants.
///
/// [all] builds a "review everything" session that also pulls in cards
/// scheduled for later, which is what the empty state offers once the day's
/// work is done. [cram] goes one step further and drops the daily caps too, so
/// a deck finished a minute ago can be studied again from the top.
/// A null [deckId] is the global queue. A record is used as the family key
/// because records compare by value, so Riverpod caches the queues separately.
typedef StudyQuery = ({String? deckId, bool all, bool cram});

/// The cards a review session should show. Loaded once per session.
final AutoDisposeFutureProviderFamily<List<ReviewCard>, StudyQuery>
studyQueueProvider = FutureProvider.autoDispose
    .family<List<ReviewCard>, StudyQuery>((Ref ref, StudyQuery query) async {
      // Read before the first await: Riverpod stops tracking dependencies
      // once a provider body has suspended, so a watch after it would not
      // rebuild the queue when the freeze changes.
      final Set<String> frozen = ref.watch(frozenDeckIdsProvider);
      final List<ReviewCard> queue = await ref
          .watch(contentRepositoryProvider)
          .studyQueue(
            query.deckId,
            newLimit: ref.watch(dailyNewLimitProvider),
            reviewLimit: ref.watch(dailyReviewLimitProvider),
            includeFuture: query.all || query.cram,
            cram: query.cram,
          );
      if (query.deckId != null || frozen.isEmpty) {
        return queue;
      }
      return <ReviewCard>[
        for (final ReviewCard card in queue)
          if (!frozen.contains(card.deckId)) card,
      ];
    });

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
    // A frozen deck's cards are still scheduled, but the learner cannot answer
    // them today, so counting them would promise work the session cannot show.
    if (deck.frozen) {
      continue;
    }
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
    if (deck.frozen) {
      continue;
    }
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
/// Auto-disposed: only the deck detail screen shows these numbers.
final AutoDisposeStreamProviderFamily<DeckStatistics, String>
deckStatisticsProvider = StreamProvider.autoDispose
    .family<DeckStatistics, String>(
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
