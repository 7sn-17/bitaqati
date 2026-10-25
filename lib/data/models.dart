import 'package:flutter/material.dart';

@immutable
class Deck {
  const Deck({
    required this.id,
    required this.title,
    this.description = '',
    this.parentId,
    this.color,
    this.icon,
    this.cardCount = 0,
    this.dueCount = 0,
    this.isPublic = false,
    this.author,
    this.rating,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String? parentId; // If null, it's a root deck. If set, it's a sub-deck.
  final Color? color;
  final IconData? icon;
  final int cardCount;
  final int dueCount;
  final bool isPublic;
  final String? author;
  final double? rating;
  final DateTime? createdAt;

  bool get isSubdeck => parentId != null;
  double get progress => (dueCount / (cardCount > 0 ? cardCount : 1)).clamp(0, 1);
}

@immutable
class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.deckId,
    required this.cardFront,
    required this.cardBack,
    this.hint,
    this.note,
    this.tags = const <String>[],
  });

  final String id;
  final String deckId;
  final String cardFront;
  final String cardBack;
  final String? hint;
  final String? note;
  final List<String> tags;
}
