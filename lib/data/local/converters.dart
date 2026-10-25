import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a `List<String>` (tags, deck path) as a JSON array in SQLite.
class StringsConverter extends TypeConverter<List<String>, String> {
  const StringsConverter();

  @override
  List<String> fromSql(String fromDb) {
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is! List<Object?>) {
      return const <String>[];
    }
    return decoded.whereType<String>().toList(growable: false);
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Stores a JSON object (deck settings, FSRS snapshots) as text in SQLite.
class JsonMapConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonMapConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) {
    final Object? decoded = jsonDecode(fromDb);
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
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is List<Object?>) {
      return decoded;
    }
    return const <Object?>[];
  }

  @override
  String toSql(List<Object?> value) => jsonEncode(value);
}
