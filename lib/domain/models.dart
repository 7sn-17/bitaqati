import 'package:flutter/material.dart';

/// Icons a deck can use. The key is what gets stored in `decks.icon`.
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
};

/// Colours offered in the deck editor. The first one is the default.
const List<Color> kDeckColors = <Color>[
  Color(0xFF163300),
  Color(0xFF054D28),
  Color(0xFF0B4C72),
  Color(0xFF4A3F7A),
  Color(0xFF7A3E2F),
  Color(0xFF8A5A00),
  Color(0xFF1F6F78),
  Color(0xFF9C2F5B),
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
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? hint;
  final String? note;
  final List<String> tags;
  final CardPhase phase;

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
    this.isPublic = false,
    this.ownCardCount = 0,
    this.cardCount = 0,
    this.dueNew = 0,
    this.dueLearning = 0,
    this.dueReview = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.childCount = 0,
    this.author,
    this.rating,
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
  final bool isPublic;
  final int ownCardCount;
  final int cardCount;
  final int dueNew;
  final int dueLearning;
  final int dueReview;
  final int reviewCount;
  final int correctCount;
  final int childCount;
  final String? author;
  final double? rating;
  final List<DeckNode> children;

  IconData get icon => kDeckIcons[iconKey] ?? Icons.layers_rounded;

  int get dueCount => dueNew + dueLearning + dueReview;

  bool get isRoot => parentId == null;

  /// Library decks shown before the cloud library is connected.
  bool get isPreview => author != null;

  /// Share of answers rated hard or better, 0 to 100.
  double get retention =>
      reviewCount == 0 ? 0 : correctCount / reviewCount * 100;

  double get progress {
    final double ratio = retention / 100;
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
      isPublic: isPublic,
      ownCardCount: ownCardCount,
      cardCount: cardCount,
      dueNew: dueNew,
      dueLearning: dueLearning,
      dueReview: dueReview,
      reviewCount: reviewCount,
      correctCount: correctCount,
      childCount: childCount,
      author: author,
      rating: rating,
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
