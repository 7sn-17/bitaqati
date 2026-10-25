import 'package:flutter/material.dart';

enum SubjectId { physics, chemistry, biology, historyOfMedicine, english1 }
enum FsrsRating { again, hard, good, easy }

@immutable
class Subject {
  const Subject({required this.id, required this.nameAr, required this.nameEn, required this.color, required this.icon});
  final SubjectId id; final String nameAr; final String nameEn; final Color color; final IconData icon;
}

const List<Subject> kSubjects = <Subject>[
  Subject(id: SubjectId.physics, nameAr: 'الفيزياء', nameEn: 'Physics', color: Color(0xFF0B4C72), icon: Icons.bolt_rounded),
  Subject(id: SubjectId.chemistry, nameAr: 'الكيمياء', nameEn: 'Chemistry', color: Color(0xFF054D28), icon: Icons.science_rounded),
  Subject(id: SubjectId.biology, nameAr: 'البيولوجيا', nameEn: 'Biology', color: Color(0xFF163300), icon: Icons.biotech_rounded),
  Subject(id: SubjectId.historyOfMedicine, nameAr: 'تاريخ الطب', nameEn: 'History of Medicine', color: Color(0xFF7A3E2F), icon: Icons.history_edu_rounded),
  Subject(id: SubjectId.english1, nameAr: 'الانكليزية 1', nameEn: 'English 1', color: Color(0xFF4A3F7A), icon: Icons.translate_rounded),
];

Subject subjectById(SubjectId id) => kSubjects.firstWhere((s) => s.id == id);

@immutable
class DeckSummary {
  const DeckSummary({
    required this.id, required this.title, required this.subjectId,
    this.description = '', this.parentId, this.colorHex = '#163300', this.iconKey = 'folder',
    this.privacy = 'private', this.tags = const [], this.isPublic = false,
    this.isStarter = false, this.isArchived = false, this.position = 0, this.depth = 0,
    this.createdAt, this.updatedAt, this.publishedAt, this.sourceTemplateId,
    this.directCardCount = 0, this.subdeckCount = 0, this.descendantDeckCount = 0,
    this.newCount = 0, this.learningCount = 0, this.reviewStateCount = 0,
    this.dueReviewCount = 0, this.masteredCount = 0, this.suspendedCount = 0, this.retentionSample = 0.0,
    this.children = const [],
  });
  final String id; final String title; final String description; final String? parentId;
  final SubjectId subjectId; final String colorHex; final String iconKey; final String privacy;
  final List<String> tags; final bool isPublic; final bool isStarter; final bool isArchived;
  final int position; final int depth; final DateTime? createdAt; final DateTime? updatedAt;
  final DateTime? publishedAt; final String? sourceTemplateId;
  final int directCardCount; final int subdeckCount; final int descendantDeckCount;
  final int newCount; final int learningCount; final int reviewStateCount;
  final int dueReviewCount; final int masteredCount; final int suspendedCount; final double retentionSample;
  final List<DeckSummary> children;

  Subject get subject => subjectById(subjectId);
  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  IconData get deckIcon {
    switch (iconKey) {
      case 'bolt': return Icons.bolt_rounded;
      case 'science': return Icons.science_rounded;
      case 'biotech': return Icons.biotech_rounded;
      case 'history': return Icons.history_edu_rounded;
      case 'translate': return Icons.translate_rounded;
      default: return Icons.folder_rounded;
    }
  }
  double get progress => (retentionSample / 100).clamp(0.0, 1.0);
  String get summary => description; // Added to fix 'summary' getter error
}

@immutable
class ReviewCard {
  const ReviewCard({
    required this.id, required this.deckId, required this.front, required this.back,
    this.hint, this.note, this.notes, this.tags = const [], this.kind = 'basic',
    this.position = 0, this.createdAt, this.updatedAt, this.fsrs, this.isSuspended = false, this.isBuried = false,
  });
  final String id; final String deckId; final String front; final String back;
  final String? hint; final String? note; final String? notes; final List<String> tags;
  final String kind; final int position; final DateTime? createdAt; final DateTime? updatedAt;
  final String? fsrs; final bool isSuspended; final bool isBuried;
}

typedef CardSummary = ReviewCard;

@immutable
class ImportedCard {
  const ImportedCard({required this.front, required this.back, this.hint, this.note, this.notes, this.tags = const []});
  final String front; final String back; final String? hint; final String? note; final String? notes; final List<String> tags;
}

@immutable
class DailyCount {
  const DailyCount({required this.date, required this.count});
  final DateTime date; final int count;
}

@immutable
class DashboardStats {
  const DashboardStats({
    this.dueCount = 0, this.newCount = 0, this.streak = 0, this.reviewsToday = 0,
    this.retention = 0.0, this.totalCards = 0, this.totalReviews = 0,
  });
  final int dueCount; final int newCount; final int streak; final int reviewsToday;
  final double retention; final int totalCards; final int totalReviews;
}

@immutable
class ReviewEvent {
  const ReviewEvent({
    required this.id, required this.deckId, required this.cardId, required this.rating,
    required this.reviewedAt, this.scheduledDays = 0, this.stability = 0.0, this.difficulty = 0.0, this.elapsedMs = 0,
  });
  final String id; final String deckId; final String cardId; final FsrsRating rating;
  final DateTime reviewedAt; final int scheduledDays; final double stability; final double difficulty; final int elapsedMs;
}

@immutable
class LibraryItem {
  const LibraryItem({required this.deck, this.authorName = 'مجهول', this.rating = 0.0, this.isOfficial = false});
  final DeckSummary deck; final String authorName; final double rating; final bool isOfficial;
  
  String get title => deck.title;
  String get description => deck.description;
  String get deckId => deck.id;
  String get colorHex => deck.colorHex;
  String get iconKey => deck.iconKey;
  int get cardCount => deck.directCardCount;
  int get subdeckCount => deck.subdeckCount;
  List<String> get tags => deck.tags;
  String? get sourceTemplateId => deck.sourceTemplateId;
}

@immutable
class Catalog {
  const Catalog({
    this.roots = const [], this.allDecks = const [], this.deckById = const {},
    this.cardsByDeck = const {}, this.cardById = const {}, this.reviews = const [],
    this.generatedAt, this.displayName = 'مستخدم', this.dashboard = const DashboardStats(),
    this.popularTags = const [], this.communityLibraryItems = const [], this.officialLibraryItems = const [],
  });
  final List<DeckSummary> roots; final List<DeckSummary> allDecks; final Map<String, DeckSummary> deckById;
  final Map<String, List<ReviewCard>> cardsByDeck; final Map<String, ReviewCard> cardById;
  final List<ReviewEvent> reviews; final DateTime? generatedAt; final String displayName;
  final DashboardStats dashboard; final List<String> popularTags;
  final List<LibraryItem> communityLibraryItems; final List<LibraryItem> officialLibraryItems;
}
