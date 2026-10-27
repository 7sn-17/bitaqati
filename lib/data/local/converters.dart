import 'dart:convert';

import 'package:drift/drift.dart';

/// Decodes JSON text without ever throwing.
///
/// A converter that throws on a malformed row takes the whole query down with
/// it: a Drift stream that maps over a failing converter emits an error, and
/// every screen that watches it sees nothing at all. One bad tag list would
/// therefore blank an entire deck while its card count stayed correct. Rows
/// are allowed to be wrong; they are not allowed to hide their neighbours.
Object? _decode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

/// Stores a `List<String>` (tags, deck path) as a JSON array in SQLite.
///
/// Also reads the comma-separated form used before the column held JSON, so a
/// database written by an older build keeps its tags instead of losing them.
class StringsConverter extends TypeConverter<List<String>, String> {
  const StringsConverter();

  @override
  List<String> fromSql(String fromDb) {
    final Object? decoded = _decode(fromDb);
    if (decoded is List<Object?>) {
      return decoded.whereType<String>().toList(growable: false);
    }
    if (decoded != null) {
      return const <String>[];
    }
    return fromDb
        .split(',')
        .map((String tag) => tag.trim())
        .where((String tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Stores a JSON object (deck settings, FSRS snapshots) as text in SQLite.
class JsonMapConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonMapConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) {
    final Object? decoded = _decode(fromDb);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return const <String, Object?>{};
  }

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);
}

/// Stores a JSON array (card media attachments) as text in SQLite.
class JsonListConverter extends TypeConverter<List<Object?>, String> {
  const JsonListConverter();

  @override
  List<Object?> fromSql(String fromDb) {
    final Object? decoded = _decode(fromDb);
    if (decoded is List<Object?>) {
      return decoded;
    }
    return const <Object?>[];
  }

  @override
  String toSql(List<Object?> value) => jsonEncode(value);
}
