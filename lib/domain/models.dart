import 'package:flutter/material.dart';

import 'enums.dart';

/// Icons a deck can use. The key is what gets stored in `decks.icon`.
///
/// The keys are stable: never rename one without a data migration, because
/// existing decks reference them by name.
const Map<String, IconData> kDeckIcons = <String, IconData>{
  'layers': Icons.layers_rounded,
  'bolt': Icons.bolt_rounded,
  'science': Icons.science_rounded,
  'biotech': Icons.biotech_rounded,
  'history': Icons.history_edu_rounded,
  'translate': Icons.translate_rounded,
  'book': Icons.menu_book_rounded,
  'calculate': Icons.calculate_rounded,
  'code': Icons.code_rounded,
  'medical': Icons.medical_services_rounded,
  'palette': Icons.palette_rounded,
  'globe': Icons.public_rounded,
  'psychology': Icons.psychology_rounded,
  'functions': Icons.functions_rounded,
  'numbers': Icons.exposure_rounded,
  'gavel': Icons.gavel_rounded,
  'business': Icons.business_center_rounded,
  'music': Icons.music_note_rounded,
  'computer': Icons.computer_rounded,
  'architecture': Icons.straighten_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'quiz': Icons.live_help_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'law': Icons.account_balance_rounded,
  'health': Icons.favorite_rounded,
  'agriculture': Icons.eco_rounded,
  'astronomy': Icons.wb_sunny_rounded,
  'sports': Icons.sports_soccer_rounded,
};

/// Colours offered in the deck editor. The first one is the default.
///
/// Every entry is dark enough for the white icon and label used on the deck
/// hero card, in both light and dark themes.
const List<Color> kDeckColors = <Color>[
  Color(0xFF163300),
  Color(0xFF054D28),
  Color(0xFF0B4C72),
  Color(0xFF4A3F7A),
  Color(0xFF7A3E2F),
  Color(0xFF8A5A00),
  Color(0xFF1F6F78),
  Color(0xFF9C2F5B),
  Color(0xFF6B21A8),
  Color(0xFF0F766E),
  Color(0xFFB45309),
  Color(0xFFBE123C),
  Color(0xFF1E3A8A),
  Color(0xFF3F6212),
  Color(0xFF831843),
  Color(0xFF0C4A6E),
  Color(0xFF334155),
  Color(0xFF1F2937),
];

const String kDefaultDeckColorHex = '#163300';

/// `#RRGGBB`, the format stored in `decks.color_hex`.
String colorToHex(Color color) {
  final int rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color colorFromHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return kDeckColors.first;
  }
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// The deck hierarchy is exactly two levels deep.
///
/// A *main deck* sits at [kMainDeckDepth] and may only contain sub-decks. A
/// *sub-deck* sits at [kSubDeckDepth] and may only contain cards. Nothing may
/// be nested below a sub-deck, so [kMaxDeckDepth] is the deepest legal depth.
const int kMainDeckDepth = 0;
const int kSubDeckDepth = 1;
const int kMaxDeckDepth = kSubDeckDepth;

/// Where a card is in its learning cycle, as far as the UI cares.
enum CardPhase { newCard, learning, review, paused }

@immutable
class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.hint,
    this.note,
    this.tags = const <String>[],
    this.phase = CardPhase.newCard,
    this.type = 'basic',
    this.due,
    this.lapses = 0,
    this.scheduledDays = 0,
    this.suspended = false,
    this.favorite = false,
    this.occlusion,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? hint;
  final String? note;
  final List<String> tags;
  final CardPhase phase;
  final String type;
  final DateTime? due;
  final int lapses;
  final int scheduledDays;
  final bool suspended;
  final bool favorite;

  /// Image-occlusion geometry: `{'boxes': [...]}` in normalised coordinates.
  /// Null for every other card type.
  final Map<String, Object?>? occlusion;

  bool get isLeech => lapses >= 4;

  bool get isDue {
    final DateTime? value = due;
    return value != null && !value.isAfter(DateTime.now());
  }

  /// 0 new, 1 learning, 2 settled. Matches the dots in the card list.
  int get stateIndex {
    switch (phase) {
      case CardPhase.newCard:
        return 0;
      case CardPhase.learning:
        return 1;
      case CardPhase.review:
      case CardPhase.paused:
        return 2;
    }
  }
}

/// How many cards are waiting, split by kind.
@immutable
class DueTotals {
  const DueTotals({this.fresh = 0, this.learning = 0, this.review = 0});

  final int fresh;
  final int learning;
  final int review;

  int get total => fresh + learning + review;
}

/// One node of the deck tree: a root deck, a sub-deck, or a lesson.
///
/// Counts on a node cover its whole subtree, so a parent deck shows the
/// totals of everything nested under it. [ownCardCount] is only the cards
/// that sit directly in this deck.
@immutable
class DeckNode {
  const DeckNode({
    required this.id,
    required this.title,
    required this.color,
    this.parentId,
    this.rootId,
    this.depth = 0,
    this.position = 0,
    this.description = '',
    this.iconKey = 'layers',
    this.tags = const <String>[],
    this.privacy = DeckPrivacy.private,
    this.isPublic = false,
    this.publishedAt,
    this.sourceDeckId,
    this.ownCardCount = 0,
    this.cardCount = 0,
    this.masteredCount = 0,
    this.dueNew = 0,
    this.dueLearning = 0,
    this.dueReview = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.childCount = 0,
    this.author,
    this.rating,
    this.ratingCount = 0,
    this.installCount = 0,
    this.children = const <DeckNode>[],
  });

  final String id;
  final String? parentId;
  final String? rootId;
  final int depth;
  final int position;
  final String title;
  final String description;
  final Color color;
  final String iconKey;
  final List<String> tags;
  final DeckPrivacy privacy;
  final bool isPublic;
  final DateTime? publishedAt;
  final String? sourceDeckId;
  final int ownCardCount;
  final int cardCount;

  /// Cards in this deck (and its sub-decks) that reached the review state.
  final int masteredCount;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviewCount;
  final int correctCount;
  final int childCount;
  final String? author;
  final double? rating;
  final int ratingCount;
  final int installCount;
  final List<DeckNode> children;

  IconData get icon => kDeckIcons[iconKey] ?? Icons.layers_rounded;

  int get dueCount => dueNew + dueLearning + dueReview;

  bool get isRoot => parentId == null;

  /// A main deck is the top level of the hierarchy: it groups sub-decks.
  bool get isMainDeck => depth == kMainDeckDepth;

  /// Anything below the top level is a sub-deck. Legacy rows that were nested
  /// deeper than the two-level rule are treated as sub-decks as well, so they
  /// keep working instead of disappearing from the UI.
  bool get isSubDeck => !isMainDeck;

  /// Only main decks may contain sub-decks; the depth limit is one level.
  bool get canHoldSubDecks => isMainDeck;

  /// Only sub-decks hold cards. Main decks never do.
  bool get canHoldCards => isSubDeck;

  /// A deck that came from the public library or a share link.
  bool get isPreview => author != null;

  bool get isUnlisted => privacy == DeckPrivacy.unlisted;

  bool get isPublished => privacy != DeckPrivacy.private;

  /// Share of answers rated hard or better, 0 to 100.
  double get retention =>
      reviewCount == 0 ? 0 : correctCount / reviewCount * 100;

  /// Share of cards that have reached the review state.
  double get masteryPercent =>
      cardCount == 0 ? 0 : masteredCount / cardCount * 100;

  /// Progress bars measure mastered cards, not answer accuracy. This keeps a
  /// one-card deck from looking empty after its first successful review.
  double get progress {
    final double ratio = cardCount == 0 ? 0 : masteredCount / cardCount;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  /// True when this deck, or anything nested in it, carries [tag].
  bool hasTag(String tag) {
    if (tags.contains(tag)) {
      return true;
    }
    for (final DeckNode child in children) {
      if (child.hasTag(tag)) {
        return true;
      }
    }
    return false;
  }

  DeckNode copyWith({List<DeckNode>? children}) {
    return DeckNode(
      id: id,
      title: title,
      color: color,
      parentId: parentId,
      rootId: rootId,
      depth: depth,
      position: position,
      description: description,
      iconKey: iconKey,
      tags: tags,
      privacy: privacy,
      isPublic: isPublic,
      publishedAt: publishedAt,
      sourceDeckId: sourceDeckId,
      ownCardCount: ownCardCount,
      cardCount: cardCount,
      masteredCount: masteredCount,
      dueNew: dueNew,
      dueLearning: dueLearning,
      dueReview: dueReview,
      reviewCount: reviewCount,
      correctCount: correctCount,
      childCount: childCount,
      author: author,
      rating: rating,
      ratingCount: ratingCount,
      installCount: installCount,
      children: children ?? this.children,
    );
  }
}

/// Turns the flat list from the database into trees, one per root deck.
///
/// A deck whose parent is missing is treated as a root so it never vanishes.
List<DeckNode> buildDeckForest(List<DeckNode> flat) {
  final Set<String> ids = flat.map((DeckNode deck) => deck.id).toSet();
  final Map<String, List<DeckNode>> byParent = <String, List<DeckNode>>{};
  final List<DeckNode> roots = <DeckNode>[];
  for (final DeckNode node in flat) {
    final String? parent = node.parentId;
    if (parent == null || !ids.contains(parent)) {
      roots.add(node);
    } else {
      byParent.putIfAbsent(parent, () => <DeckNode>[]).add(node);
    }
  }

  DeckNode attach(DeckNode node) {
    final List<DeckNode> kids = byParent[node.id] ?? const <DeckNode>[];
    return node.copyWith(children: kids.map(attach).toList(growable: false));
  }

  return roots.map(attach).toList(growable: false);
}

/// Every node of [forest], parents before their children.
List<DeckNode> flattenDeckForest(List<DeckNode> forest) {
  final List<DeckNode> out = <DeckNode>[];
  void visit(DeckNode node) {
    out.add(node);
    node.children.forEach(visit);
  }

  forest.forEach(visit);
  return out;
}

DeckNode? findDeckNode(List<DeckNode> forest, String id) {
  for (final DeckNode node in forest) {
    if (node.id == id) {
      return node;
    }
    final DeckNode? nested = findDeckNode(node.children, id);
    if (nested != null) {
      return nested;
    }
  }
  return null;
}

/// One day of review history, used by the progress heatmap and streaks.
@immutable
class ReviewActivityDay {
  const ReviewActivityDay({
    required this.day,
    required this.reviews,
    required this.correct,
  });

  final DateTime day;
  final int reviews;
  final int correct;
}

/// How many cards are due on one of the next seven days.
@immutable
class DueForecastDay {
  const DueForecastDay({required this.day, required this.count});

  final DateTime day;
  final int count;
}

/// Real statistics for a deck and, when it is a main deck, its sub-decks.
@immutable
class DeckStatistics {
  const DeckStatistics({
    this.totalCards = 0,
    this.newCards = 0,
    this.learningCards = 0,
    this.dueCards = 0,
    this.matureCards = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
  });

  final int totalCards;
  final int newCards;
  final int learningCards;
  final int dueCards;
  final int matureCards;
  final int reviewCount;
  final int correctCount;

  double get retention =>
      reviewCount == 0 ? 0 : correctCount / reviewCount * 100;

  double get maturity =>
      totalCards == 0 ? 0 : matureCards / totalCards;

  double get maturityPercent => maturity * 100;
}

/// A deck row ready to be written to Supabase.
@immutable
class DeckBundleNode {
  const DeckBundleNode({
    required this.id,
    required this.parentId,
    required this.depth,
    required this.position,
    required this.title,
    this.description = '',
    this.colorHex,
    this.icon = 'layers',
    this.tags = const <String>[],
    this.settings = const <String, Object?>{},
    this.coverUrl,
    this.sourceDeckId,
    this.sourceVersion = 1,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? parentId;
  final int depth;
  final int position;
  final String title;
  final String description;
  final String? colorHex;
  final String icon;
  final List<String> tags;
  final Map<String, Object?> settings;
  final String? coverUrl;
  final String? sourceDeckId;
  final int sourceVersion;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// A card row ready to be written to Supabase.
@immutable
class DeckBundleCard {
  const DeckBundleCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.position,
    this.type = 'basic',
    this.notes = '',
    this.hint = '',
    this.tags = const <String>[],
    this.media = const <Object?>[],
    this.occlusion,
    this.source,
    this.aiGenerated = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String deckId;
  final String type;
  final String front;
  final String back;
  final String notes;
  final String hint;
  final List<String> tags;
  final List<Object?> media;
  final Map<String, Object?>? occlusion;
  final String? source;
  final bool aiGenerated;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// A deck subtree and its cards, used for publishing and for installing a
/// deck from the library or a share link.
@immutable
class DeckBundle {
  const DeckBundle({
    required this.root,
    required this.nodes,
    required this.cards,
  });

  final DeckNode root;
  final List<DeckBundleNode> nodes;
  final List<DeckBundleCard> cards;
}
