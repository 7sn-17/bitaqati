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

/// A deck. Decks are a flat list: each one owns its cards directly, and
/// nothing nests. [cardCount] is the number of live cards in the deck.
@immutable
class DeckNode {
  const DeckNode({
    required this.id,
    required this.title,
    required this.color,
    this.position = 0,
    this.description = '',
    this.iconKey = 'layers',
    this.tags = const <String>[],
    this.privacy = DeckPrivacy.private,
    this.isPublic = false,
    this.publishedAt,
    this.sourceDeckId,
    this.originalDeckId,
    this.originalAuthorName,
    this.shareCode,
    this.cardCount = 0,
    this.masteredCount = 0,
    this.dueNew = 0,
    this.dueLearning = 0,
    this.dueReview = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.author,
    this.rating,
    this.ratingCount = 0,
    this.installCount = 0,
  });

  final String id;
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

  /// First deck in the remix chain. Null when this deck is not a remix.
  final String? originalDeckId;

  /// Author of the original deck, captured when this copy was installed.
  final String? originalAuthorName;

  /// Six-character code used to share and find the deck in the library.
  final String? shareCode;

  final int cardCount;

  /// Cards in this deck that reached the review state.
  final int masteredCount;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviewCount;
  final int correctCount;
  final String? author;
  final double? rating;
  final int ratingCount;
  final int installCount;

  IconData get icon => kDeckIcons[iconKey] ?? Icons.layers_rounded;

  int get dueCount => dueNew + dueLearning + dueReview;

  /// True when the deck can be found by its share code.
  bool get isShareable => (shareCode ?? '').isNotEmpty;

  /// A deck that came from the public library or a share link.
  bool get isPreview => author != null;

  /// True when this deck was installed from someone else's work.
  bool get isRemix => (originalAuthorName ?? '').isNotEmpty;

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

  /// True when the deck carries [tag].
  bool hasTag(String tag) => tags.contains(tag);

  DeckNode copyWith({
    String? title,
    String? description,
    Color? color,
    String? iconKey,
    List<String>? tags,
    DeckPrivacy? privacy,
    bool? isPublic,
    int? position,
    String? shareCode,
    int? cardCount,
    int? masteredCount,
    int? dueNew,
    int? dueLearning,
    int? dueReview,
    int? reviewCount,
    int? correctCount,
    String? author,
    double? rating,
    int? ratingCount,
    int? installCount,
  }) {
    return DeckNode(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      iconKey: iconKey ?? this.iconKey,
      tags: tags ?? this.tags,
      privacy: privacy ?? this.privacy,
      isPublic: isPublic ?? this.isPublic,
      publishedAt: publishedAt,
      sourceDeckId: sourceDeckId,
      originalDeckId: originalDeckId,
      originalAuthorName: originalAuthorName,
      shareCode: shareCode ?? this.shareCode,
      position: position ?? this.position,
      cardCount: cardCount ?? this.cardCount,
      masteredCount: masteredCount ?? this.masteredCount,
      dueNew: dueNew ?? this.dueNew,
      dueLearning: dueLearning ?? this.dueLearning,
      dueReview: dueReview ?? this.dueReview,
      reviewCount: reviewCount ?? this.reviewCount,
      correctCount: correctCount ?? this.correctCount,
      author: author ?? this.author,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      installCount: installCount ?? this.installCount,
    );
  }
}

/// Looks a deck up in a flat list.
DeckNode? findDeckNode(List<DeckNode> decks, String id) {
  for (final DeckNode node in decks) {
    if (node.id == id) {
      return node;
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

/// Real statistics for a single deck.
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
    required this.position,
    required this.title,
    this.description = '',
    this.colorHex,
    this.icon = 'layers',
    this.tags = const <String>[],
    this.settings = const <String, Object?>{},
    this.coverUrl,
    this.sourceDeckId,
    this.originalDeckId,
    this.originalAuthorName,
    this.sourceVersion = 1,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int position;
  final String title;
  final String description;
  final String? colorHex;
  final String icon;
  final List<String> tags;
  final Map<String, Object?> settings;
  final String? coverUrl;
  final String? sourceDeckId;
  final String? originalDeckId;
  final String? originalAuthorName;
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

/// A deck and its cards, used for publishing and for installing a deck from
/// the library or a share link.
@immutable
class DeckBundle {
  const DeckBundle({required this.deck, required this.row, required this.cards});

  final DeckNode deck;
  final DeckBundleNode row;
  final List<DeckBundleCard> cards;
}
