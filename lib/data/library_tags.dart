import 'package:flutter/material.dart';

import '../domain/models.dart';

/// A tag shown as a tile on the library screen.
@immutable
class LibraryTag {
  const LibraryTag({
    required this.id,
    required this.nameAr,
    required this.color,
    required this.icon,
    required this.count,
  });

  final String id;
  final String nameAr;
  final Color color;
  final IconData icon;
  final int count;
}

/// One tile per first tag found in [decks], in order of appearance.
List<LibraryTag> buildLibraryTags(List<DeckNode> decks) {
  final List<String> order = <String>[];
  final Map<String, DeckNode> firstDeck = <String, DeckNode>{};
  final Map<String, int> counts = <String, int>{};
  for (final DeckNode deck in decks) {
    if (deck.tags.isEmpty) {
      continue;
    }
    final String tag = deck.tags.first;
    if (!counts.containsKey(tag)) {
      order.add(tag);
      firstDeck[tag] = deck;
    }
    counts[tag] = (counts[tag] ?? 0) + 1;
  }
  final List<LibraryTag> tiles = <LibraryTag>[];
  for (final String tag in order) {
    final DeckNode? source = firstDeck[tag];
    if (source == null) {
      continue;
    }
    tiles.add(
      LibraryTag(
        id: tag,
        nameAr: tag,
        color: source.color,
        icon: source.icon,
        count: counts[tag] ?? 0,
      ),
    );
  }
  return tiles;
}
