import 'package:flutter/foundation.dart';

/// A card that has been written but not saved yet.
///
/// The smart import flow holds a list of these between the moment the text is
/// parsed and the moment the user presses save, so a draft can be opened in
/// the full editor, edited, and put back without ever touching the database.
@immutable
class CardDraft {
  const CardDraft({
    this.front = '',
    this.back = '',
    this.hint = '',
    this.note = '',
    this.tags = const <String>[],
    this.type = 'basic',
    this.occlusion,
  });

  final String front;
  final String back;
  final String hint;
  final String note;
  final List<String> tags;

  /// Card layout: `basic`, `cloze` or `occlusion`. Mirrors the local enum.
  final String type;

  /// Image-occlusion geometry, null for every other card type.
  final Map<String, Object?>? occlusion;

  /// True when the draft has enough content to become a card.
  bool get isReady => front.trim().isNotEmpty && back.trim().isNotEmpty;

  CardDraft copyWith({
    String? front,
    String? back,
    String? hint,
    String? note,
    List<String>? tags,
    String? type,
    Map<String, Object?>? occlusion,
  }) {
    return CardDraft(
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      occlusion: occlusion ?? this.occlusion,
    );
  }
}
