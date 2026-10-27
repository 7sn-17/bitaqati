import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

export 'converters.dart';

/// Card layout. Mirrors the cloud `card_type` enum.
enum CardType { basic, cloze, mcq, occlusion }

/// Scheduling status of a card. Mirrors the cloud `card_state` enum.
///
/// `new` is a reserved word in Dart, so the first value is [newCard]. Use
/// [CardStatusCloud.cloudValue] and [cardStatusFromCloud] when syncing.
enum CardStatus { newCard, learning, review, relearning, suspended, buried }

/// What a queued sync entry should do on the server.
enum SyncOperation { upsert, delete }

extension CardStatusCloud on CardStatus {
  String get cloudValue {
    switch (this) {
      case CardStatus.newCard:
        return 'new';
      case CardStatus.learning:
        return 'learning';
      case CardStatus.review:
        return 'review';
      case CardStatus.relearning:
        return 'relearning';
      case CardStatus.suspended:
        return 'suspended';
      case CardStatus.buried:
        return 'buried';
    }
  }
}

CardStatus cardStatusFromCloud(String value) {
  switch (value) {
    case 'learning':
      return CardStatus.learning;
    case 'review':
      return CardStatus.review;
    case 'relearning':
      return CardStatus.relearning;
    case 'suspended':
      return CardStatus.suspended;
    case 'buried':
      return CardStatus.buried;
    default:
      return CardStatus.newCard;
  }
}

/// The signed-in user's profile, as this device knows it.
///
/// The display name lives here so a name chosen in Settings survives a
/// sign-out, a reinstall, and a device that is offline. Supabase keeps the
/// authoritative copy for the public library.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get userId => text()();

  /// Empty until the user picks a name; the UI then falls back to the name
  /// Google returned.
  TextColumn get displayName => text().withDefault(const Constant(''))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

/// A deck. Decks are a flat list: each one owns its cards directly.
///
/// Ids are client-generated UUID strings so rows can be created offline and
/// pushed to Supabase unchanged.
@DataClassName('DeckRow')
@TableIndex(name: 'decks_owner_idx', columns: {#ownerId})
@TableIndex(name: 'decks_share_code_idx', columns: {#shareCode})
class Decks extends Table {
  TextColumn get id => text()();

  /// Null until the user signs in; filled in during the first sync.
  TextColumn get ownerId => text().nullable()();

  /// Six-character code used to share the deck. Unique per account.
  TextColumn get shareCode => text().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  TextColumn get title => text().withLength(min: 1, max: 160)();

  TextColumn get description => text().withDefault(const Constant(''))();

  TextColumn get colorHex => text().nullable()();

  TextColumn get icon => text().withDefault(const Constant('layers'))();

  TextColumn get privacy =>
      textEnum<DeckPrivacy>().withDefault(const Constant('private'))();

  TextColumn get coverUrl => text().nullable()();

  /// Free-form labels. These replace the old hardcoded subject list.
  TextColumn get tags =>
      text().map(const StringsConverter()).withDefault(const Constant('[]'))();

  /// Per-deck scheduler overrides (new_per_day, desired_retention, ...).
  TextColumn get settings =>
      text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();

  BoolColumn get isStarter => boolean().withDefault(const Constant(false))();

  /// Set when this deck is a copy of a public deck.
  TextColumn get sourceDeckId => text().nullable()();

  /// First deck in the remix chain. Null when this deck is not a remix.
  TextColumn get originalDeckId => text().nullable()();

  /// Display name of the original author, captured when the deck was
  /// installed so the credit survives the original being deleted.
  TextColumn get originalAuthorName => text().nullable()();

  IntColumn get sourceVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get forkedAt => dateTime().nullable()();

  DateTimeColumn get publishedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft delete: a non-null value hides the row and syncs as a deletion.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CardRow')
@TableIndex(name: 'cards_deck_idx', columns: {#deckId, #position})
class Cards extends Table {
  TextColumn get id => text()();

  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();

  TextColumn get type =>
      textEnum<CardType>().withDefault(const Constant('basic'))();

  TextColumn get front => text().withDefault(const Constant(''))();

  TextColumn get back => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  TextColumn get hint => text().withDefault(const Constant(''))();

  TextColumn get tags =>
      text().map(const StringsConverter()).withDefault(const Constant('[]'))();

  /// Attachments: a JSON array of `{kind, url, ...}` objects.
  TextColumn get media =>
      text().map(const JsonListConverter()).withDefault(const Constant('[]'))();

  /// Image-occlusion geometry; null for every other card type.
  TextColumn get occlusion => text().map(const JsonMapConverter()).nullable()();

  TextColumn get source => text().nullable()();

  BoolColumn get aiGenerated => boolean().withDefault(const Constant(false))();

  /// Locally pinned cards shown first in review and the card list.
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  IntColumn get position => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// FSRS-6 memory state of one card for the local user (one row per card).
///
/// Every timestamp here is an instant: Drift stores [DateTime] columns as Unix
/// epoch seconds, so a value written as UTC reads back as the same instant in
/// whatever timezone the device happens to be in. The scheduler still writes
/// [due] and [lastReview] from `DateTime.now().toUtc()` because FSRS maths is
/// defined in UTC and a device that changes timezone must not shift a card's
/// memory state.
///
/// [stability] and [difficulty] are the two numbers FSRS needs to remember.
/// A row written by the old fixed-interval scheduler has both at 0, which is
/// impossible for a real FSRS card (stability has a floor of 0.001), so 0 is
/// the marker [FsrsEngine] uses to re-seed a legacy card on its next review.
@DataClassName('CardStateRow')
@TableIndex(name: 'card_states_due_idx', columns: {#status, #due})
class CardStates extends Table {
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();

  TextColumn get status =>
      textEnum<CardStatus>().withDefault(const Constant('newCard'))();

  /// Next review instant, always written in UTC.
  DateTimeColumn get due => dateTime().withDefault(currentDateAndTime)();

  /// Days until the memory of this card decays to 90 % recall. 0 means the
  /// card has never been scheduled by FSRS.
  RealColumn get stability => real().withDefault(const Constant(0.0))();

  /// How hard this card is for this user, 1 (easy) to 10 (hard). 0 means the
  /// card has never been scheduled by FSRS.
  RealColumn get difficulty => real().withDefault(const Constant(0.0))();

  /// Whole days between the previous review and this one, as FSRS saw them.
  IntColumn get elapsedDays => integer().withDefault(const Constant(0))();

  /// Whole days FSRS asked for when it scheduled this card. 0 for the short
  /// learning steps, which are measured in minutes.
  IntColumn get scheduledDays => integer().withDefault(const Constant(0))();

  /// Index into the scheduler's learning or relearning steps, i.e. FSRS's
  /// `Card.step`. Synced as `learning_steps` for backwards compatibility with
  /// the cloud column of the same name. 0 while the card sits on step one.
  IntColumn get learningSteps => integer().withDefault(const Constant(0))();

  IntColumn get reps => integer().withDefault(const Constant(0))();

  IntColumn get lapses => integer().withDefault(const Constant(0))();

  /// Instant of the last answer, always written in UTC.
  DateTimeColumn get lastReview => dateTime().nullable()();

  /// Which scheduler produced [stability] and [difficulty]. 0 means the row
  /// predates FSRS and must be re-seeded on its next review.
  ///
  /// Kept local-only: the cloud copy of the row carries the same numbers, and
  /// [FsrsEngine] treats `stability > 0` as FSRS state too, so a state pulled
  /// onto a fresh device is never mistaken for a legacy one.
  IntColumn get fsrsVersion => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {cardId};
}

/// Append-only history of answers. Never edited, so it never conflicts.
@DataClassName('ReviewLogRow')
@TableIndex(name: 'review_logs_card_idx', columns: {#cardId, #reviewedAt})
@TableIndex(name: 'review_logs_time_idx', columns: {#reviewedAt})
class ReviewLogs extends Table {
  /// Client-generated UUID; becomes `client_id` in the cloud table, which
  /// makes pushing the same log twice harmless.
  TextColumn get id => text()();

  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();

  /// 1 again, 2 hard, 3 good, 4 easy.
  IntColumn get rating => integer()();

  DateTimeColumn get reviewedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get elapsedMs => integer().nullable()();

  IntColumn get scheduledDays => integer().nullable()();

  RealColumn get stability => real().nullable()();

  RealColumn get difficulty => real().nullable()();

  TextColumn get prevState => text().map(const JsonMapConverter()).nullable()();

  TextColumn get nextState => text().map(const JsonMapConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (rating BETWEEN 1 AND 4)',
  ];
}

/// Changes waiting to be pushed to Supabase, oldest first.
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Table name: decks, cards, card_states or review_logs.
  TextColumn get entity => text()();

  TextColumn get entityId => text()();

  TextColumn get operation => textEnum<SyncOperation>()();

  TextColumn get payload => text().map(const JsonMapConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();
}

/// Small key/value store for sync cursors and migration flags.
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
