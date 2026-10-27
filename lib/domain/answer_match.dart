import 'dart:math' as math;

/// The result of comparing a typed answer with the card's answer.
class AnswerCheck {
  const AnswerCheck({required this.correct, required this.similarity});

  final bool correct;

  /// 0..1. Never shown as a number, but it decides how forgiving the verdict is
  /// and lets the UI say "قريب جداً" instead of a flat "خطأ".
  final double similarity;
}

/// Arabic-aware answer comparison.
///
/// A learner who types «الخليه» for «الخلية» made a spelling slip, not a memory
/// failure, so the comparison folds the orthography before it measures the
/// distance: hamza forms, ta marbuta, alef maqsura, tashkeel and tatweel all
/// collapse to one spelling first.
///
/// The tolerance scales with length on purpose. A three-letter answer has no
/// room for a typo — «DNA» and «RNA» differ by one character and by everything
/// — while a fifteen-letter one can absorb two slips and still be the same
/// answer.
AnswerCheck checkAnswer(String expected, String typed) {
  final String answer = normalizeAnswer(expected);
  final String given = normalizeAnswer(typed);
  if (answer.isEmpty || given.isEmpty) {
    return const AnswerCheck(correct: false, similarity: 0);
  }
  if (answer == given) {
    return const AnswerCheck(correct: true, similarity: 1);
  }
  // A multi-word answer counts when every word is there, in any order: the
  // learner recalled all of it, they just wrote it differently.
  final List<String> answerWords = answer.split(' ');
  final List<String> givenWords = given.split(' ');
  if (answerWords.length > 1 &&
      givenWords.length >= answerWords.length &&
      answerWords.every(givenWords.contains)) {
    return const AnswerCheck(correct: true, similarity: 0.96);
  }
  final int distance = _levenshtein(answer, given);
  final int longest = math.max(answer.length, given.length);
  final double ratio = 1 - distance / longest;
  final int allowed = switch (longest) {
    <= 4 => 0,
    <= 8 => 1,
    _ => math.max(2, (longest * 0.15).floor()),
  };
  return AnswerCheck(
    correct: distance <= allowed && ratio >= 0.72,
    similarity: ratio,
  );
}

/// Folds the spelling differences that Arabic writers disagree about, drops
/// diacritics and punctuation, and collapses whitespace.
String normalizeAnswer(String value) {
  final StringBuffer folded = StringBuffer();
  for (final int rune in value.toLowerCase().runes) {
    final String char = String.fromCharCode(rune);
    if (_diacritics.contains(char) || char == '\u0640') {
      continue;
    }
    folded.write(_folds[char] ?? char);
  }
  return folded
      .toString()
      .replaceAll(_punctuation, ' ')
      .replaceAll(_whitespace, ' ')
      .trim();
}

const Set<String> _diacritics = <String>{
  '\u064B',
  '\u064C',
  '\u064D',
  '\u064E',
  '\u064F',
  '\u0650',
  '\u0651',
  '\u0652',
  '\u0670',
};

const Map<String, String> _folds = <String, String>{
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ة': 'ه',
  'ى': 'ي',
  'ئ': 'ي',
  'ؤ': 'و',
};

final RegExp _punctuation = RegExp(r'''[.,;:!?"'()\[\]{}\-_/\\،؛؟«»…]''');

final RegExp _whitespace = RegExp(r'\s+');

/// Classic two-row Levenshtein. The strings here are a card answer, not a
/// document, so the quadratic table would be waste.
int _levenshtein(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }
  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  List<int> current = List<int>.filled(b.length + 1, 0);
  for (int i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (int j = 0; j < b.length; j++) {
      final int cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final int deletion = previous[j + 1] + 1;
      final int insertion = current[j] + 1;
      final int substitution = previous[j] + cost;
      current[j + 1] = math.min(math.min(deletion, insertion), substitution);
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}
