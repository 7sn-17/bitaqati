import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum String { physics, chemistry, biology, historyOfMedicine, english1 }

@immutable
class Subject {
  const Subject({required this.id, required this.nameAr, required this.nameEn, required this.color, required this.icon, required this.sortOrder});
  final String id; final String nameAr; final String nameEn; final Color color; final IconData icon; final int sortOrder;
}

const List<Subject> kSubjects = <Subject>[
  Subject(id: String.physics, nameAr: 'الفيزياء', nameEn: 'Physics', color: AppColors.physics, icon: Icons.bolt_rounded, sortOrder: 1),
  Subject(id: String.chemistry, nameAr: 'الكيمياء', nameEn: 'Chemistry', color: AppColors.chemistry, icon: Icons.science_rounded, sortOrder: 2),
  Subject(id: String.biology, nameAr: 'البيولوجيا', nameEn: 'Biology', color: AppColors.biology, icon: Icons.biotech_rounded, sortOrder: 3),
  Subject(id: String.historyOfMedicine, nameAr: 'تاريخ الطب', nameEn: 'History of Medicine', color: AppColors.medicineHistory, icon: Icons.history_edu_rounded, sortOrder: 4),
  Subject(id: String.english1, nameAr: 'الانكليزية 1', nameEn: 'English 1', color: AppColors.english, icon: Icons.translate_rounded, sortOrder: 5),
];

Subject subjectById(String id) => kSubjects.firstWhere((Subject subject) => subject.id == id);

@immutable
class DeckSummary {
  const DeckSummary({
    required this.id, required this.title, required this.subjectId,
    required this.cardCount, required this.dueCount, required this.retention,
    required this.isPublic, this.parentId, this.author, this.rating,
  });
  final String id; final String title; final String subjectId;
  final int cardCount; final int dueCount; final double retention;
  final bool isPublic; final String? parentId; final String? author; final double? rating;
  
  Subject get subject => subjectById(subjectId);
  double get progress => (retention / 100).clamp(0, 1);
}

const List<DeckSummary> kMyDecks = <DeckSummary>[
  DeckSummary(id: 'biology-cell', title: 'البيولوجيا · الخلية', subjectId: String.biology, cardCount: 120, dueCount: 9, retention: 91, isPublic: false),
  DeckSummary(id: 'chemistry-organic', title: 'الكيمياء العضوية', subjectId: String.chemistry, cardCount: 86, dueCount: 6, retention: 76, isPublic: true),
  DeckSummary(id: 'physics-motion', title: 'الفيزياء · الحركة', subjectId: String.physics, cardCount: 48, dueCount: 0, retention: 88, isPublic: false),
  DeckSummary(id: 'medicine-history', title: 'تاريخ الطب · الثورة الجراحية', subjectId: String.historyOfMedicine, cardCount: 64, dueCount: 3, retention: 82, isPublic: false),
  DeckSummary(id: 'english-unit-1', title: 'الانكليزية 1 · الوحدة الأولى', subjectId: String.english1, cardCount: 80, dueCount: 6, retention: 74, isPublic: true),
];

const List<DeckSummary> kLibraryDecks = <DeckSummary>[
  DeckSummary(id: 'public-biology', title: 'البيولوجيا · الخلية كاملة', subjectId: String.biology, cardCount: 120, dueCount: 0, retention: 0, isPublic: true, author: 'عبدالله', rating: 4.8),
  DeckSummary(id: 'public-chemistry', title: 'كيمياء عضوية: التفاعلات', subjectId: String.chemistry, cardCount: 86, dueCount: 0, retention: 0, isPublic: true, author: 'مريم', rating: 4.6),
  DeckSummary(id: 'public-history', title: 'تاريخ الطب · رواد الجراحة', subjectId: String.historyOfMedicine, cardCount: 72, dueCount: 0, retention: 0, isPublic: true, author: 'سارة', rating: 4.9),
  DeckSummary(id: 'public-english', title: 'الانكليزية 1 · مفردات شاملة', subjectId: String.english1, cardCount: 150, dueCount: 0, retention: 0, isPublic: true, author: 'نور', rating: 4.7),
  DeckSummary(id: 'public-physics', title: 'الفيزياء · قوانين نيوتن', subjectId: String.physics, cardCount: 44, dueCount: 0, retention: 0, isPublic: true, author: 'حسين', rating: 4.5),
];

@immutable
class ReviewCard {
  const ReviewCard({
    required this.id, required this.deckId, required this.subjectId,
    required this.front, required this.back, this.hint, this.note, this.tags = const <String>[],
  });
  final String id; final String deckId; final String subjectId;
  final String front; final String back; final String? hint; final String? note; final List<String> tags;
}

const List<ReviewCard> kSampleCards = <ReviewCard>[
  ReviewCard(id: 'card-1', deckId: 'biology-cell', subjectId: String.biology, front: 'ما وظيفة الميتوكوندريا في الخلية الحيوانية؟', back: 'إنتاج الطاقة على شكل ATP عبر التنفس الخلوي.', hint: 'تُسمّى بيت الطاقة.', note: 'تكثر في خلايا العضلات لأنها تحتاج طاقة كبيرة.', tags: <String>['ATP', 'التنفس الخلوي']),
  ReviewCard(id: 'card-2', deckId: 'biology-cell', subjectId: String.biology, front: 'أين تحدث الغلكزة؟', back: 'في السيتوبلازم.', tags: <String>['الخلية', 'الغلكزة']),
  ReviewCard(id: 'card-4', deckId: 'physics-motion', subjectId: String.physics, front: 'ما هو قانون نيوتن الثاني؟', back: 'القوة تساوي الكتلة مضروبة في التسارع: F = ma.', note: 'وحدة القوة هي النيوتن (N).', tags: <String>['نيوتن', 'القوة']),
  ReviewCard(id: 'card-10', deckId: 'english-unit-1', subjectId: String.english1, front: 'What is the past tense of "study"?', back: 'studied', tags: <String>['grammar', 'past tense']),
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
