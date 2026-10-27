import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Sample public decks shown on the library screen until it is connected to
/// the Supabase `public_decks` view. They are previews only: they have no
/// cards and cannot be copied yet.
const List<DeckNode> kLibraryDecks = <DeckNode>[
  DeckNode(
    id: 'public-biology',
    title: 'البيولوجيا · الخلية كاملة',
    color: Color(0xFF163300),
    iconKey: 'biotech',
    tags: <String>['البيولوجيا'],
    isPublic: true,
    ownCardCount: 120,
    cardCount: 120,
    author: 'عبدالله',
    rating: 4.8,
  ),
  DeckNode(
    id: 'public-chemistry',
    title: 'كيمياء عضوية: التفاعلات',
    color: Color(0xFF054D28),
    iconKey: 'science',
    tags: <String>['الكيمياء'],
    isPublic: true,
    ownCardCount: 86,
    cardCount: 86,
    author: 'مريم',
    rating: 4.6,
  ),
  DeckNode(
    id: 'public-history',
    title: 'تاريخ الطب · رواد الجراحة',
    color: Color(0xFF7A3E2F),
    iconKey: 'history',
    tags: <String>['تاريخ الطب'],
    isPublic: true,
    ownCardCount: 72,
    cardCount: 72,
    author: 'سارة',
    rating: 4.9,
  ),
  DeckNode(
    id: 'public-english',
    title: 'الانكليزية 1 · مفردات شاملة',
    color: Color(0xFF4A3F7A),
    iconKey: 'translate',
    tags: <String>['الانكليزية'],
    isPublic: true,
    ownCardCount: 150,
    cardCount: 150,
    author: 'نور',
    rating: 4.7,
  ),
  DeckNode(
    id: 'public-physics',
    title: 'الفيزياء · قوانين نيوتن',
    color: Color(0xFF0B4C72),
    iconKey: 'bolt',
    tags: <String>['الفيزياء'],
    isPublic: true,
    ownCardCount: 44,
    cardCount: 44,
    author: 'حسين',
    rating: 4.5,
  ),
];

DeckNode? findLibraryDeck(String id) {
  for (final DeckNode deck in kLibraryDecks) {
    if (deck.id == id) {
      return deck;
    }
  }
  return null;
}

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

final List<LibraryTag> kLibraryTags = buildLibraryTags(kLibraryDecks);
