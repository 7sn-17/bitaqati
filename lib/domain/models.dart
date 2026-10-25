import 'dart:math' as math;

import 'enums.dart';
import 'fsrs.dart';

class DeckSummary {
  const DeckSummary({
    required this.id,
    required this.parentId,
    required this.title,
    required this.description,
    required this.colorHex,
    required this.iconKey,
    required this.privacy,
    required this.tags,
    required this.isStarter,
    required this.isArchived,
    required this.position,
    required this.depth,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.sourceTemplateId,
    required this.directCardCount,
    required this.cardCount,
    required this.subdeckCount,
    required this.descendantDeckCount,
    required this.newCount,
    required this.learningCount,
    required this.reviewStateCount,
    required this.dueReviewCount,
    required this.dueCount,
    required this.masteredCount,
    required this.suspendedCount,
    required this.retention,
    required this.retentionSample,
  });

  final String id;
  final String? parentId;
  final String title;
  final String description;
  final String colorHex;
  final String iconKey;
  final DeckPrivacy privacy;
  final List<String> tags;
  final bool isStarter;
  final bool isArchived;
  final int position;
  final int depth;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final String? sourceTemplateId;
  final int directCardCount;
  final int cardCount;
  final int subdeckCount;
  final int descendantDeckCount;
  final int newCount;
  final int learningCount;
  final int reviewStateCount;
  final int dueReviewCount;
  final int dueCount;
  final int masteredCount;
  final int suspendedCount;

  /// Percentage 0..100 of predicted recall across reviewed cards.
  final double retention;
  final int retentionSample;

  bool get isRoot => parentId == null;
  bool get isPublic => privacy == DeckPrivacy.public;
  bool get isUnlisted => privacy == DeckPrivacy.unlisted;
  bool get isShared => privacy != DeckPrivacy.private;
  bool get hasChildren => subdeckCount > 0;
  bool get isEmpty => cardCount == 0 && subdeckCount == 0;
  double get progress => (retention / 100).clamp(0.0, 1.0);
}

class CardSummary {
  const CardSummary({
    required this.id,
    required this.deckId,
    required this.cardFront,
    required this.back,
    required this.hint,
    required this.notes,
    required this.kind,
    required this.tags,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    required this.fsrs,
    required this.isSuspended,
    required this.isBuried,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String hint;
  final String notes;
  final CardKind kind;
  final List<String> tags;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FsrsCard fsrs;
  final bool isSuspended;
  final bool isBuried;

  bool get isNew => fsrs.state == FsrsState.newCard || fsrs.reps == 0;
  bool get isDue =>
      !isSuspended && !isBuried && fsrs.due.isBefore(DateTime.now().toUtc());
  bool get isLeech => fsrs.lapses >= 8;

  CardSummary copyWith({
    FsrsCard? fsrs,
    bool? isSuspended,
    bool? isBuried,
    String? front,
    String? back,
    String? hint,
    String? notes,
  }) {
    return CardSummary(
      id: id,
      deckId: deckId,
      front: front ?? this.cardFront,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      notes: notes ?? this.notes,
      kind: kind,
      tags: tags,
      position: position,
      createdAt: createdAt,
      updatedAt: updatedAt,
      fsrs: fsrs ?? this.fsrs,
      isSuspended: isSuspended ?? this.isSuspended,
      isBuried: isBuried ?? this.isBuried,
    );
  }
}

class DeckNode {
  const DeckNode({required this.summary, required this.children});

  final DeckSummary summary;
  final List<DeckNode> children;
}

class ReviewEvent {
  const ReviewEvent({
    required this.id,
    required this.cardId,
    required this.deckId,
    required this.rating,
    required this.reviewedAt,
    required this.scheduledDays,
    required this.stability,
    required this.difficulty,
    this.elapsedMs,
  });

  final String id;
  final String cardId;
  final String deckId;
  final FsrsRating rating;
  final DateTime reviewedAt;
  final int scheduledDays;
  final double stability;
  final double difficulty;
  final int? elapsedMs;

  bool get isSuccessful =>
      rating == FsrsRating.good || rating == FsrsRating.easy;
}

class ImportedCard {
  const ImportedCard({
    required this.cardFront,
    required this.back,
    this.hint = '',
    this.notes = '',
    this.tags = const <String>[],
  });

  final String front;
  final String back;
  final String hint;
  final String notes;
  final List<String> tags;
}

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.colorHex,
    required this.iconKey,
    required this.tags,
    required this.cardCount,
    required this.subdeckCount,
    required this.authorName,
    required this.rating,
    required this.isOfficial,
    required this.isInstalled,
    this.deckId,
    this.sourceTemplateId,
  });

  final String id;
  final String? deckId;
  final String? sourceTemplateId;
  final String title;
  final String description;
  final String colorHex;
  final String iconKey;
  final List<String> tags;
  final int cardCount;
  final int subdeckCount;
  final String authorName;
  final double rating;
  final bool isOfficial;
  final bool isInstalled;
}

class DashboardStats {
  const DashboardStats({
    required this.dueCount,
    required this.newCount,
    required this.learningCount,
    required this.reviewStateCount,
    required this.totalCards,
    required this.totalDecks,
    required this.reviewsToday,
    required this.streak,
    required this.retention,
    required this.masteredCount,
    required this.continueDeck,
    required this.nextDueAt,
  });

  final int dueCount;
  final int newCount;
  final int learningCount;
  final int reviewStateCount;
  final int totalCards;
  final int totalDecks;
  final int reviewsToday;
  final int streak;
  final double retention;
  final int masteredCount;
  final DeckNode? continueDeck;
  final DateTime? nextDueAt;
}

class DailyCount {
  const DailyCount({required this.date, required this.count});

  final DateTime date;
  final int count;
}

class ProgressStats {
  const ProgressStats({
    required this.rangeDays,
    required this.retention,
    required this.streak,
    required this.reviewsToday,
    required this.reviewsInRange,
    required this.totalReviews,
    required this.forecast,
    required this.heatmap,
    required this.topDecks,
    required this.deckReviewCounts,
    required this.leeches,
  });

  final int rangeDays;
  final double retention;
  final int streak;
  final int reviewsToday;
  final int reviewsInRange;
  final int totalReviews;
  final List<DailyCount> forecast;
  final List<DailyCount> heatmap;
  final List<DeckNode> topDecks;
  final Map<String, int> deckReviewCounts;
  final List<CardSummary> leeches;
}

class SearchResult {
  const SearchResult({required this.decks, required this.cards});

  final List<DeckNode> decks;
  final List<CardSummary> cards;

  bool get isEmpty => decks.isEmpty && cards.isEmpty;
  int get total => decks.length + cards.length;
}

class Catalog {
  const Catalog({
    required this.roots,
    required this.allDecks,
    required this.deckById,
    required this.cardsByDeck,
    required this.cardById,
    required this.reviews,
    required this.generatedAt,
    this.displayName,
  });

  final List<DeckNode> roots;
  final List<DeckNode> allDecks;
  final Map<String, DeckNode> deckById;
  final Map<String, List<CardSummary>> cardsByDeck;
  final Map<String, CardSummary> cardById;
  final List<ReviewEvent> reviews;
  final DateTime generatedAt;
  final String? displayName;

  List<CardSummary> get allCards => cardById.values.toList(growable: false);

  List<DeckNode> childrenOf(String? parentId) {
    if (parentId == null) {
      return roots;
    }
    return deckById[parentId]?.children ?? const <DeckNode>[];
  }

  DeckNode? deck(String id) => deckById[id];

  List<DeckNode> pathTo(String id) {
    final List<DeckNode> path = <DeckNode>[];
    String? cursor = id;
    while (cursor != null) {
      final DeckNode? node = deckById[cursor];
      if (node == null) {
        break;
      }
      path.add(node);
      cursor = node.summary.parentId;
    }
    return path.reversed.toList(growable: false);
  }

  List<CardSummary> cardsInDeck(
    String deckId, {
    bool includeDescendants = true,
    bool publicOnly = false,
  }) {
    final DeckNode? root = deckById[deckId];
    if (root == null) {
      return const <CardSummary>[];
    }
    final List<CardSummary> result = <CardSummary>[];
    void visit(DeckNode node) {
      if (publicOnly && node.summary.privacy != DeckPrivacy.public) {
        return;
      }
      result.addAll(cardsByDeck[node.summary.id] ?? const <CardSummary>[]);
      if (includeDescendants) {
        for (final DeckNode child in node.children) {
          visit(child);
        }
      }
    }

    visit(root);
    return result;
  }

  int publicCardCount(String deckId) {
    return cardsInDeck(deckId, publicOnly: true).length;
  }

  int publicSubdeckCount(String deckId) {
    final DeckNode? root = deckById[deckId];
    if (root == null) {
      return 0;
    }
    int count = 0;
    void visit(DeckNode node) {
      for (final DeckNode child in node.children) {
        if (child.summary.privacy == DeckPrivacy.public) {
          count += 1;
          visit(child);
        }
      }
    }

    visit(root);
    return count;
  }

  bool hasPublicAncestor(DeckNode node) {
    String? parentId = node.summary.parentId;
    while (parentId != null) {
      final DeckNode? parent = deckById[parentId];
      if (parent == null) {
        break;
      }
      if (parent.summary.privacy == DeckPrivacy.public) {
        return true;
      }
      parentId = parent.summary.parentId;
    }
    return false;
  }

  List<DeckNode> get publicStandaloneDecks {
    final List<DeckNode> result = allDecks
        .where(
          (DeckNode node) =>
              node.summary.privacy == DeckPrivacy.public &&
              !hasPublicAncestor(node),
        )
        .toList(growable: false);
    result.sort(_compareDecks);
    return result;
  }

  List<LibraryItem> get communityLibraryItems {
    final String author = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : '';
    return publicStandaloneDecks
        .map(
          (DeckNode node) => LibraryItem(
            id: node.summary.id,
            deckId: node.summary.id,
            title: node.summary.title,
            description: node.summary.description,
            colorHex: node.summary.colorHex,
            iconKey: node.summary.iconKey,
            tags: node.summary.tags,
            cardCount: publicCardCount(node.summary.id),
            subdeckCount: publicSubdeckCount(node.summary.id),
            authorName: author,
            rating: 0,
            isOfficial: false,
            isInstalled: true,
          ),
        )
        .toList(growable: false);
  }

  List<String> get popularTags {
    final Map<String, int> counts = <String, int>{};
    for (final DeckNode node in allDecks) {
      for (final String tag in node.summary.tags) {
        final String clean = tag.trim();
        if (clean.isEmpty) {
          continue;
        }
        counts[clean] = (counts[clean] ?? 0) + 1;
      }
    }
    final List<String> tags = counts.keys.toList(growable: false);
    tags.sort((String a, String b) {
      final int byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
    return tags.take(14).toList(growable: false);
  }

  SearchResult search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const SearchResult(decks: <DeckNode>[], cards: <CardSummary>[]);
    }
    final List<DeckNode> decks = allDecks
        .where(
          (DeckNode node) =>
              node.summary.title.toLowerCase().contains(q) ||
              node.summary.description.toLowerCase().contains(q) ||
              node.summary.tags.any(
                (String tag) => tag.toLowerCase().contains(q),
              ),
        )
        .take(30)
        .toList(growable: false);
    final List<CardSummary> cards = allCards
        .where(
          (CardSummary card) =>
              card.cardFront.toLowerCase().contains(q) ||
              card.back.toLowerCase().contains(q) ||
              card.hint.toLowerCase().contains(q) ||
              card.notes.toLowerCase().contains(q) ||
              card.tags.any((String tag) => tag.toLowerCase().contains(q)),
        )
        .take(50)
        .toList(growable: false);
    return SearchResult(decks: decks, cards: cards);
  }

  DashboardStats dashboard() {
    final DateTime now = generatedAt.toLocal();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int reviewsToday = reviews
        .where(
          (ReviewEvent event) => _sameDay(event.reviewedAt.toLocal(), today),
        )
        .length;
    final int dueCount = roots.fold<int>(
      0,
      (int value, DeckNode node) => value + node.summary.dueCount,
    );
    final int newCount = roots.fold<int>(
      0,
      (int value, DeckNode node) => value + node.summary.newCount,
    );
    final int learningCount = roots.fold<int>(
      0,
      (int value, DeckNode node) => value + node.summary.learningCount,
    );
    final int reviewStateCount = roots.fold<int>(
      0,
      (int value, DeckNode node) => value + node.summary.reviewStateCount,
    );
    final int masteredCount = roots.fold<int>(
      0,
      (int value, DeckNode node) => value + node.summary.masteredCount,
    );
    final List<DeckNode> dueRoots = roots
        .where((DeckNode node) => node.summary.dueCount > 0)
        .toList(growable: false);
    dueRoots.sort(
      (DeckNode a, DeckNode b) =>
          b.summary.dueCount.compareTo(a.summary.dueCount),
    );
    DateTime? nextDue;
    for (final CardSummary card in allCards) {
      if (card.isSuspended || card.isBuried) {
        continue;
      }
      if (card.fsrs.due.isAfter(generatedAt)) {
        if (nextDue == null || card.fsrs.due.isBefore(nextDue)) {
          nextDue = card.fsrs.due;
        }
      }
    }
    return DashboardStats(
      dueCount: dueCount,
      newCount: newCount,
      learningCount: learningCount,
      reviewStateCount: reviewStateCount,
      totalCards: allCards.length,
      totalDecks: allDecks.length,
      reviewsToday: reviewsToday,
      streak: _streak(today),
      retention: _retention(now.subtract(const Duration(days: 30))),
      masteredCount: masteredCount,
      continueDeck: dueRoots.isEmpty ? null : dueRoots.first,
      nextDueAt: nextDue,
    );
  }

  ProgressStats progress({int days = 30}) {
    final DateTime now = generatedAt.toLocal();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start = today.subtract(
      Duration(days: math.max(0, days - 1)),
    );
    final List<ReviewEvent> rangeReviews = reviews
        .where(
          (ReviewEvent event) => !event.reviewedAt.toLocal().isBefore(start),
        )
        .toList(growable: false);
    final int reviewsToday = reviews
        .where(
          (ReviewEvent event) => _sameDay(event.reviewedAt.toLocal(), today),
        )
        .length;
    final int successful = rangeReviews
        .where((ReviewEvent event) => event.isSuccessful)
        .length;
    final double retention = rangeReviews.isEmpty
        ? 0
        : (successful / rangeReviews.length) * 100;

    final Map<String, int> reviewsByDeck = <String, int>{};
    for (final ReviewEvent event in rangeReviews) {
      reviewsByDeck[event.deckId] = (reviewsByDeck[event.deckId] ?? 0) + 1;
    }
    final List<DeckNode> topDecks = reviewsByDeck.keys
        .map((String id) => deckById[id])
        .whereType<DeckNode>()
        .toList(growable: false);
    topDecks.sort(
      (DeckNode a, DeckNode b) => (reviewsByDeck[b.summary.id] ?? 0).compareTo(
        reviewsByDeck[a.summary.id] ?? 0,
      ),
    );

    final List<DailyCount> forecast = <DailyCount>[];
    final Map<String, int> dueByDay = <String, int>{};
    for (final CardSummary card in allCards) {
      if (card.isSuspended ||
          card.isBuried ||
          card.fsrs.state == FsrsState.newCard) {
        continue;
      }
      final DateTime due = card.fsrs.due.toLocal();
      final DateTime day = DateTime(due.year, due.month, due.day);
      if (day.isBefore(today) ||
          day.isAfter(today.add(const Duration(days: 29)))) {
        continue;
      }
      final String key = _dayKey(day);
      dueByDay[key] = (dueByDay[key] ?? 0) + 1;
    }
    for (int i = 0; i < 30; i += 1) {
      final DateTime day = today.add(Duration(days: i));
      forecast.add(DailyCount(date: day, count: dueByDay[_dayKey(day)] ?? 0));
    }

    final List<DailyCount> heatmap = <DailyCount>[];
    final Map<String, int> reviewsByDay = <String, int>{};
    for (final ReviewEvent event in reviews) {
      final DateTime local = event.reviewedAt.toLocal();
      final String key = _dayKey(local);
      reviewsByDay[key] = (reviewsByDay[key] ?? 0) + 1;
    }
    final DateTime heatmapStart = today.subtract(const Duration(days: 83));
    for (int i = 0; i < 84; i += 1) {
      final DateTime day = heatmapStart.add(Duration(days: i));
      heatmap.add(
        DailyCount(date: day, count: reviewsByDay[_dayKey(day)] ?? 0),
      );
    }

    final List<CardSummary> leeches = allCards
        .where((CardSummary card) => card.isLeech)
        .toList(growable: false);
    leeches.sort(
      (CardSummary a, CardSummary b) => b.fsrs.lapses.compareTo(a.fsrs.lapses),
    );

    return ProgressStats(
      rangeDays: days,
      retention: retention,
      streak: _streak(today),
      reviewsToday: reviewsToday,
      reviewsInRange: rangeReviews.length,
      totalReviews: reviews.length,
      forecast: forecast,
      heatmap: heatmap,
      topDecks: topDecks.take(5).toList(growable: false),
      deckReviewCounts: reviewsByDeck,
      leeches: leeches.take(20).toList(growable: false),
    );
  }

  int _streak(DateTime today) {
    final Set<String> days = reviews
        .map((ReviewEvent event) => _dayKey(event.reviewedAt.toLocal()))
        .toSet();
    DateTime cursor = today;
    if (!days.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (days.contains(_dayKey(cursor)) && streak < 3650) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _retention(DateTime start) {
    final List<ReviewEvent> range = reviews
        .where(
          (ReviewEvent event) => !event.reviewedAt.toLocal().isBefore(start),
        )
        .toList(growable: false);
    if (range.isEmpty) {
      return 0;
    }
    final int successful = range
        .where((ReviewEvent event) => event.isSuccessful)
        .length;
    return (successful / range.length) * 100;
  }

  static int _compareDecks(DeckNode a, DeckNode b) {
    final int byDue = b.summary.dueCount.compareTo(a.summary.dueCount);
    if (byDue != 0) {
      return byDue;
    }
    return a.summary.title.compareTo(b.summary.title);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dayKey(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
