import 'package:flutter/foundation.dart';

import '../domain/card_draft.dart';

/// What one pass over pasted text produced.
@immutable
class CardImportResult {
  const CardImportResult({required this.drafts, required this.skipped});

  final List<CardDraft> drafts;

  /// Lines that were not usable: no separator, or an empty side.
  final int skipped;

  bool get isEmpty => drafts.isEmpty;
}

/// Turns pasted text into draft cards.
///
/// One card per line, fields separated by a pipe:
///
/// ```text
/// Front | Back
/// Front | Back | Hint
/// Front | Back | Hint | Note
/// ```
///
/// Anything else is counted as skipped rather than guessed at, because a
/// wrong card is worse than a missing one. A backslash before a pipe keeps
/// the pipe inside the field, which matters for code and chemistry.
CardImportResult parseCardImport(String text) {
  final List<CardDraft> drafts = <CardDraft>[];
  int skipped = 0;

  for (final String rawLine in text.split(RegExp(r'\r?\n'))) {
    final String line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    final List<String> fields = _splitRow(line);
    if (fields.length < 2) {
      skipped++;
      continue;
    }
    final String front = fields[0].trim();
    final String back = fields[1].trim();
    if (front.isEmpty || back.isEmpty) {
      skipped++;
      continue;
    }
    // Extra separators are folded into the note instead of being dropped,
    // so a line with five fields still keeps all of its text.
    final String hint = fields.length > 2 ? fields[2].trim() : '';
    final String note = fields.length > 3
        ? fields.sublist(3).join(' | ').trim()
        : '';
    drafts.add(CardDraft(front: front, back: back, hint: hint, note: note));
  }

  return CardImportResult(drafts: drafts, skipped: skipped);
}

/// Splits on pipes, honouring a backslash escape.
List<String> _splitRow(String line) {
  final List<String> parts = <String>[];
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < line.length; index++) {
    final String char = line[index];
    if (char == '\\' && index + 1 < line.length && line[index + 1] == '|') {
      buffer.write('|');
      index++;
      continue;
    }
    if (char == '|') {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  parts.add(buffer.toString());
  return parts;
}

/// The prompt the help sheet hands to the user.
///
/// It is deliberately explicit about the output shape and about not adding
/// commentary, because models otherwise wrap the rows in prose that the
/// parser has to throw away.
const String kSmartImportPrompt =
    'حوّل النص التالي إلى بطاقات مراجعة.\n'
    '\n'
    'القواعد:\n'
    '1. كل بطاقة في سطر مستقل.\n'
    '2. الحقول مفصولة بالرمز | بهذا الترتيب:\n'
    '   السؤال | الجواب | التلميح | الملاحظة\n'
    '3. التلميح والملاحظة اختياريان. إن لم يوجد تلميح اترك الحقل فارغاً مع إبقاء |.\n'
    '4. السؤال قصير ومحدد، والجواب لا يزيد عن سطرين.\n'
    '5. لا تكتب ترقيماً ولا عناوين ولا مقدمات ولا خاتمة.\n'
    '6. لا تستخدم | داخل النص؛ استبدله بـ /\n'
    '\n'
    'مثال على المخرجات:\n'
    'ما هو ناتج جمع 2 + 2؟ | 4 | عملية جمع بسيطة |\n'
    'ما عاصمة اليابان؟ | طوكيو | تقع على المحيط الهادئ\n'
    'ما هو الرمز الكيميائي للحديد؟ | Fe | من اللاتينية Ferrum | فلز انتقالي\n'
    '\n'
    'النص:\n';
