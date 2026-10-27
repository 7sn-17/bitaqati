import 'package:flutter/material.dart';

import '../core/scheduling/fsrs_engine.dart';
import 'enums.dart';

/// Icons a deck can use. The key is what gets stored in `decks.icon`.
///
/// The keys are stable: never rename one without a data migration, because
/// existing decks reference them by name.
const Map<String, IconData> kDeckIcons = <String, IconData>{
  // General
  'layers': Icons.layers_rounded,
  'bolt': Icons.bolt_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'quiz': Icons.live_help_rounded,
  'bookmark': Icons.bookmark_rounded,
  'star': Icons.star_rounded,
  'target': Icons.track_changes_rounded,
  'puzzle': Icons.extension_rounded,
  'rocket': Icons.rocket_launch_rounded,
  'diamond': Icons.diamond_rounded,
  'hourglass': Icons.hourglass_bottom_rounded,
  'key': Icons.key_rounded,
  // Science and medicine
  'science': Icons.science_rounded,
  'biotech': Icons.biotech_rounded,
  'chemistry': Icons.bubble_chart_rounded,
  'virus': Icons.coronavirus_rounded,
  'medical': Icons.medical_services_rounded,
  'health': Icons.favorite_rounded,
  'psychology': Icons.psychology_rounded,
  'mind': Icons.psychology_alt_rounded,
  'astronomy': Icons.wb_sunny_rounded,
  'agriculture': Icons.eco_rounded,
  'water': Icons.water_drop_rounded,
  // Maths
  'calculate': Icons.calculate_rounded,
  'functions': Icons.functions_rounded,
  'numbers': Icons.exposure_rounded,
  'statistics': Icons.bar_chart_rounded,
  'geometry': Icons.change_history_rounded,
  'percent': Icons.percent_rounded,
  'infinity': Icons.all_inclusive_rounded,
  'measure': Icons.square_foot_rounded,
  // Language
  'translate': Icons.translate_rounded,
  'language': Icons.language_rounded,
  'spellcheck': Icons.spellcheck_rounded,
  'text': Icons.text_fields_rounded,
  'voice': Icons.record_voice_over_rounded,
  'listening': Icons.headphones_rounded,
  'book': Icons.menu_book_rounded,
  // History, law and society
  'history': Icons.history_edu_rounded,
  'museum': Icons.museum_rounded,
  'castle': Icons.castle_rounded,
  'map': Icons.map_rounded,
  'flag': Icons.flag_rounded,
  'gavel': Icons.gavel_rounded,
  'law': Icons.account_balance_rounded,
  'society': Icons.groups_rounded,
  'theater': Icons.theater_comedy_rounded,
  'worship': Icons.church_rounded,
  // Technology
  'code': Icons.code_rounded,
  'computer': Icons.computer_rounded,
  'memory': Icons.memory_rounded,
  'terminal': Icons.terminal_rounded,
  'cloud': Icons.cloud_rounded,
  'security': Icons.security_rounded,
  'network': Icons.wifi_rounded,
  'mobile': Icons.smartphone_rounded,
  'database': Icons.storage_rounded,
  'bug': Icons.bug_report_rounded,
  // Arts and media
  'palette': Icons.palette_rounded,
  'brush': Icons.brush_rounded,
  'design': Icons.design_services_rounded,
  'draw': Icons.draw_rounded,
  'music': Icons.music_note_rounded,
  'piano': Icons.piano_rounded,
  'movie': Icons.movie_rounded,
  'photo': Icons.photo_camera_rounded,
  // Business and daily life
  'business': Icons.business_center_rounded,
  'money': Icons.payments_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'school': Icons.school_rounded,
  'restaurant': Icons.restaurant_rounded,
  'fitness': Icons.fitness_center_rounded,
  'sports': Icons.sports_soccer_rounded,
  'wellness': Icons.spa_rounded,
  'pets': Icons.pets_rounded,
  'car': Icons.directions_car_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'globe': Icons.public_rounded,
  'architecture': Icons.straighten_rounded,
};

/// Colours offered in the deck editor. The first one is the default.
///
/// Two families live here: deep tones that carry white text, and pale ones
/// that carry dark text. Which one a deck needs is decided by
/// [onDeckColor], never hardcoded, so a pale deck is just as readable as a
/// dark one in both themes.
const List<Color> kDeckColors = <Color>[
  // Deep: brand, jewel and earth tones.
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
  Color(0xFF7E22CE),
  Color(0xFF0E7490),
  Color(0xFF4D7C0F),
  Color(0xFF166534),
  Color(0xFF9F1239),
  Color(0xFF5B21B6),
  Color(0xFFA21CAF),
  Color(0xFF78350F),
  Color(0xFF14532D),
  Color(0xFF1E293B),
  // Pale: soft, modern tints that take dark ink.
  Color(0xFFFDE68A),
  Color(0xFFFBCFE8),
  Color(0xFFBFDBFE),
  Color(0xFFBBF7D0),
  Color(0xFFDDD6FE),
  Color(0xFFFED7AA),
  Color(0xFFA5F3FC),
  Color(0xFFF5D0FE),
  Color(0xFFFECDD3),
  Color(0xFFE0E7FF),
  Color(0xFFD9F99D),
  Color(0xFF99F6E4),
  Color(0xFFFECACA),
  Color(0xFFE7E5E4),
];

/// Ink that stays readable on top of [color].
///
/// The palette spans pale sand and near-black forest, so a fixed white
/// foreground would disappear on half of it. The crossover sits at a
/// luminance of 0.22: below that white wins on contrast, above it the near
/// black ink does, which is also where dark text stops looking muddy.
Color onDeckColor(Color color) {
  return color.computeLuminance() > 0.22
      ? const Color(0xFF0E0F0C)
      : Colors.white;
}

/// A version of a deck colour that works as *text or an icon on a surface*.
///
/// The palette is wide enough that both directions break: a pastel tone is
/// invisible on the light canvas, and a near-black forest is invisible on the
/// dark one. So each theme pulls toward its own pole — light darkens anything
/// brighter than the crossover, dark lifts anything deeper — and leaves the
/// tones that already work untouched.
Color deckInk(Color color, {required bool dark}) {
  final double luminance = color.computeLuminance();
  if (dark) {
    if (luminance >= 0.24) {
      return color;
    }
    return Color.lerp(color, Colors.white, 0.62)!;
  }
  if (luminance <= 0.35) {
    return color;
  }
  return Color.lerp(color, const Color(0xFF0E0F0C), 0.55)!;
}

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
    this.memory,
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

  /// The FSRS memory state behind [phase], or null when the card has never
  /// been scheduled. Carried on the card so the rating buttons can preview
  /// their real intervals without touching the database.
  final FsrsMemory? memory;

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

  double get maturity => totalCards == 0 ? 0 : matureCards / totalCards;

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
  const DeckBundle({
    required this.deck,
    required this.row,
    required this.cards,
  });

  final DeckNode deck;
  final DeckBundleNode row;
  final List<DeckBundleCard> cards;
}
