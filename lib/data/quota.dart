import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../core/widgets/card_markup.dart';
import '../domain/freemium.dart';
import '../domain/models.dart';
import 'content_providers.dart';

/// How much of each capped card kind the library already holds.
///
/// Counted from the cards themselves rather than kept as a running total: a
/// counter drifts the first time a card is deleted on another device and the
/// deletion syncs in, and a drifted counter either blocks a paying customer or
/// gives one away for free.
@immutable
class UsageCounts {
  const UsageCounts({
    this.cards = 0,
    this.occlusion = 0,
    this.cloze = 0,
    this.images = 0,
    this.audio = 0,
  });

  final int cards;
  final int occlusion;
  final int cloze;
  final int images;
  final int audio;

  static const UsageCounts none = UsageCounts();

  int used(QuotaKind kind) => switch (kind) {
    QuotaKind.cards => cards,
    QuotaKind.occlusion => occlusion,
    QuotaKind.cloze => cloze,
    QuotaKind.images => images,
    QuotaKind.audio => audio,
    // Neither of these is a property of the library.
    QuotaKind.importCards || QuotaKind.studySessions => 0,
  };
}

/// Every live card, ignoring the freeze.
///
/// The study providers subtract frozen decks because those cards must not be
/// studied. Counting is the opposite question: a frozen deck still occupies
/// the allowance it occupied before, and hiding it here would let a lapsed
/// account free up room by lapsing.
final StreamProvider<List<ReviewCard>> everyCardProvider =
    StreamProvider<List<ReviewCard>>(
      (Ref ref) => ref.watch(contentRepositoryProvider).watchAllCards(),
    );

final Provider<UsageCounts> usageCountsProvider = Provider<UsageCounts>((
  Ref ref,
) {
  final List<ReviewCard>? cards = ref.watch(everyCardProvider).valueOrNull;
  if (cards == null) {
    return UsageCounts.none;
  }
  int occlusion = 0;
  int cloze = 0;
  int images = 0;
  int audio = 0;
  for (final ReviewCard card in cards) {
    if (card.type == 'occlusion') {
      occlusion++;
    }
    if (card.type == 'cloze') {
      cloze++;
    }
    images +=
        kImageRegex.allMatches(card.front).length +
        kImageRegex.allMatches(card.back).length;
    audio +=
        kAudioRegex.allMatches(card.front).length +
        kAudioRegex.allMatches(card.back).length;
  }
  return UsageCounts(
    cards: cards.length,
    occlusion: occlusion,
    cloze: cloze,
    images: images,
    audio: audio,
  );
});

/// The ceilings that reset with the calendar rather than with the library.
///
/// Both counters are self-expiring: the stored blob carries the day or month it
/// belongs to, and a blob from a different period reads as zero. That is what
/// makes the reset happen without a scheduled job, and it is also what stops a
/// phone that was off for a week from counting last week's sessions against
/// today's.
class QuotaLedger {
  QuotaLedger(this._prefs);

  final SharedPreferences _prefs;

  static const String _sessionsKey = 'quota_sessions';
  static const String _importKey = 'quota_import';

  static String _day(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}';

  static String _month(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// Sessions started today for [deckId].
  int sessionsToday(String deckId, {DateTime? now}) {
    final Map<String, Object?> blob = _read(_sessionsKey);
    if (blob['day'] != _day(now ?? DateTime.now())) {
      return 0;
    }
    final Object? counts = blob['counts'];
    if (counts is! Map) {
      return 0;
    }
    final Object? value = counts[deckId];
    return value is int ? value : 0;
  }

  /// Records a session that is about to start.
  Future<void> noteSession(String deckId, {DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final String day = _day(at);
    final Map<String, Object?> blob = _read(_sessionsKey);
    final Map<String, Object?> counts = <String, Object?>{};
    if (blob['day'] == day && blob['counts'] is Map) {
      (blob['counts']! as Map<Object?, Object?>).forEach((
        Object? key,
        Object? value,
      ) {
        if (key is String) {
          counts[key] = value;
        }
      });
    }
    counts[deckId] = sessionsToday(deckId, now: at) + 1;
    await _prefs.setString(
      _sessionsKey,
      jsonEncode(<String, Object?>{'day': day, 'counts': counts}),
    );
  }

  /// Cards imported this calendar month.
  int importedThisMonth({DateTime? now}) {
    final Map<String, Object?> blob = _read(_importKey);
    if (blob['month'] != _month(now ?? DateTime.now())) {
      return 0;
    }
    final Object? value = blob['count'];
    return value is int ? value : 0;
  }

  Future<void> noteImported(int count, {DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final int total = importedThisMonth(now: at) + count;
    await _prefs.setString(
      _importKey,
      jsonEncode(<String, Object?>{'month': _month(at), 'count': total}),
    );
  }

  Map<String, Object?> _read(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <String, Object?>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
    } catch (_) {
      // A corrupted blob is the same as no blob: the counters reset rather
      // than throwing every screen that asks about them.
      return <String, Object?>{};
    }
  }
}

final Provider<QuotaLedger> quotaLedgerProvider = Provider<QuotaLedger>(
  (Ref ref) => QuotaLedger(ref.watch(sharedPreferencesProvider)),
);

/// The first ceiling [counts] has already reached, or null when there is room.
///
/// One function for every card-kind cap so the editor cannot enforce three of
/// them and forget the fourth. [adding] is what the caller is about to write:
/// a card with an image needs room for one more image, not for zero.
QuotaKind? firstExceededQuota({
  required UsageCounts counts,
  required bool free,
  int adding = 1,
  bool occlusion = false,
  bool cloze = false,
  int images = 0,
  int audio = 0,
}) {
  if (!free) {
    return null;
  }
  if (counts.cards + adding > FreeLimits.cards) {
    return QuotaKind.cards;
  }
  if (occlusion && counts.occlusion + 1 > FreeLimits.occlusionCards) {
    return QuotaKind.occlusion;
  }
  if (cloze && counts.cloze + 1 > FreeLimits.clozeCards) {
    return QuotaKind.cloze;
  }
  if (counts.images + images > FreeLimits.images) {
    return QuotaKind.images;
  }
  if (counts.audio + audio > FreeLimits.audio) {
    return QuotaKind.audio;
  }
  return null;
}
