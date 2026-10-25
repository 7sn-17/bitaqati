import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum SubjectId { physics, chemistry, biology, historyOfMedicine, english1 }

@immutable
class Subject {
  const Subject({required this.id, required this.nameAr, required this.nameEn, required this.color, required this.icon, required this.sortOrder});
  final SubjectId id; final String nameAr; final String nameEn; final Color color; final IconData icon; final int sortOrder;
}

const List<Subject> kSubjects = <Subject>[
  Subject(id: SubjectId.physics, nameAr: 'الفيزياء', nameEn: 'Physics', color: AppColors.physics, icon: Icons.bolt_rounded, sortOrder: 1),
  Subject(id: SubjectId.chemistry, nameAr: 'الكيمياء', nameEn: 'Chemistry', color: AppColors.chemistry, icon: Icons.science_rounded, sortOrder: 2),
  Subject(id: SubjectId.biology, nameAr: 'البيولوجيا', nameEn: 'Biology', color: AppColors.biology, icon: Icons.biotech_rounded, sortOrder: 3),
  Subject(id: SubjectId.historyOfMedicine, nameAr: 'تاريخ الطب', nameEn: 'History of Medicine', color: AppColors.medicineHistory, icon: Icons.history_edu_rounded, sortOrder: 4),
  Subject(id: SubjectId.english1, nameAr: 'الانكليزية 1', nameEn: 'English 1', color: AppColors.english, icon: Icons.translate_rounded, sortOrder: 5),
];

Subject subjectById(SubjectId id) => kSubjects.firstWhere((Subject subject) => subject.id == id);

extension SubjectIdX on SubjectId {
  IconData get deckIcon {
    switch (this) {
      case SubjectId.physics: return Icons.bolt_rounded;
      case SubjectId.chemistry: return Icons.science_rounded;
      case SubjectId.biology: return Icons.biotech_rounded;
      case SubjectId.historyOfMedicine: return Icons.history_edu_rounded;
      case SubjectId.english1: return Icons.translate_rounded;
    }
  }
}

@immutable
class DeckSummary {
  const DeckSummary({
    required this.id, required this.title, required this.subjectId,
    required this.cardCount, required this.dueCount, required this.retention,
    required this.isPublic, this.parentId, this.author, this.rating,
  });
  final String id; final String title; final SubjectId subjectId;
  final int cardCount; final int dueCount; final double retention;
  final bool isPublic; final String? parentId; final String? author; final double? rating;
  
  Subject get subject => subjectById(subjectId);
  double get progress => (retention / 100).clamp(0, 1);
}

extension DeckSummaryX on DeckSummary {
  IconData get deckIcon => subject.icon;
}

const List<DeckSummary> kMyDecks = <DeckSummary>[
  DeckSummary(id: 'biology-cell', title: 'البيولوجيا · الخلية', subjectId: SubjectId.biology, cardCount: 120, dueCount: 9, retention: 91, isPublic: false),
  DeckSummary(id: 'chemistry-organic', title: 'الكيمياء العضوية', subjectId: SubjectId.chemistry, cardCount: 86, dueCount: 6, retention: 76, isPublic: true),
  DeckSummary(id: 'physics-motion', title: 'الفيزياء · الحركة', subjectId: SubjectId.physics, cardCount: 48, dueCount: 0, retention: 88, isPublic: false),
  DeckSummary(id: 'medicine-history', title: 'تاريخ الطب · الثورة الجراحية', subjectId: SubjectId.historyOfMedicine, cardCount: 64, dueCount: 3, retention: 82, isPublic: false),
  DeckSummary(id: 'english-unit-1', title: 'الانكليزية 1 · الوحدة الأولى', subjectId: SubjectId.english1, cardCount: 80, dueCount: 6, retention: 74, isPublic: true),
];

const List<DeckSummary> kLibraryDecks = <DeckSummary>[
  DeckSummary(id: 'public-biology', title: 'البيولوجيا · الخلية كاملة', subjectId: SubjectId.biology, cardCount: 120, dueCount: 0, retention: 0, isPublic: true, author: 'عبدالله', rating: 4.8),
  DeckSummary(id: 'public-chemistry', title: 'كيمياء عضوية: التفاعلات', subjectId: SubjectId.chemistry, cardCount: 86, dueCount: 0, retention: 0, isPublic: true, author: 'مريم', rating: 4.6),
  DeckSummary(id: 'public-history', title: 'تاريخ الطب · رواد الجراحة', subjectId: SubjectId.historyOfMedicine, cardCount: 72, dueCount: 0, retention: 0, isPublic: true, author: 'سارة', rating: 4.9),
  DeckSummary(id: 'public-english', title: 'الانكليزية 1 · مفردات شاملة', subjectId: SubjectId.english1, cardCount: 150, dueCount: 0, retention: 0, isPublic: true, author: 'نور', rating: 4.7),
  DeckSummary(id: 'public-physics', title: 'الفيزياء · قوانين نيوتن', subjectId: SubjectId.physics, cardCount: 44, dueCount: 0, retention: 0, isPublic: true, author: 'حسين', rating: 4.5),
];

@immutable
class ReviewCard {
  const ReviewCard({
    required this.id, required this.deckId, required this.subjectId,
    required this.front, required this.back, this.hint, this.note, this.tags = const <String>[],
  });
  final String id; final String deckId; final SubjectId subjectId;
  final String front; final String back; final String? hint; final String? note; final List<String> tags;
}

const List<ReviewCard> kSampleCards = <ReviewCard>[
  ReviewCard(id: 'card-1', deckId: 'biology-cell', subjectId: SubjectId.biology, front: 'ما وظيفة الميتوكوندريا في الحيوانية؟', back: 'إنتاج الطاقة ATP.', hint: 'بيت الطاقة.', note: 'تكثر في العضلات.', tags: <String>['ATP', 'التنفس']),
  ReviewCard(id: 'card-2', deckId: 'physics-motion', subjectId: SubjectId.physics, front: 'قانون نيوتن الثاني؟', back: 'F = ma.', tags: <String>['نيوتن']),
];

List<ReviewCard> cardsForDeck(DeckSummary deck) {
  final List<ReviewCard> exact = kSampleCards.where((ReviewCard card) => card.deckId == deck.id).toList(growable: false);
  if (exact.isNotEmpty) return exact;
  return kSampleCards.where((ReviewCard card) => card.subjectId == deck.subjectId).toList(growable: false);
}

DeckSummary findDeck(String id) {
  return <DeckSummary>[...kMyDecks, ...kLibraryDecks].firstWhere(
    (DeckSummary deck) => deck.id == id,
    orElse: () => kMyDecks.first,
  );
}
