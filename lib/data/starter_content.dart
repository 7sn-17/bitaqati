import '../domain/models.dart';

class StarterCatalog {
  const StarterCatalog._();

  static const List<StarterDeck> decks = <StarterDeck>[
    StarterDeck(
      id: 'physics', titleAr: 'الفيزياء', titleEn: 'Physics',
      descriptionAr: 'أساسيات الحركة والقوى والطاقة', descriptionEn: 'Motion, forces and energy',
      colorHex: '#1D6FD1', iconKey: 'bolt', tags: <String>['فيزياء', 'Physics'], rating: 4.9,
      lessons: <StarterLesson>[
        StarterLesson(id: 'motion', titleAr: 'الحركة والقوى', titleEn: 'Motion & Forces', cards: <StarterCard>[
          StarterCard(front: 'ما نص قانون نيوتن الثاني؟', back: 'القوة = الكتلة × التسارع (F = ma).', tags: <String>['نيوتن']),
          StarterCard(front: 'ما الفرق بين السرعة والتسارع؟', back: 'السرعة تغير الموقع، التسارع تغير السرعة.', tags: <String>['السرعة']),
        ]),
        StarterLesson(id: 'energy', titleAr: 'الطاقة', titleEn: 'Energy', cards: <StarterCard>[
          StarterCard(front: 'ما مبدأ حفظ الطاقة؟', back: 'الطاقة لا تفنى ولا تستحدث.', tags: <String>['الطاقة']),
        ]),
      ],
    ),
    StarterDeck(
      id: 'chemistry', titleAr: 'الكيمياء', titleEn: 'Chemistry',
      descriptionAr: 'البنية الذرية والروابط', descriptionEn: 'Atomic structure and bonding',
      colorHex: '#0B7A5A', iconKey: 'science', tags: <String>['كيمياء'], rating: 4.8,
      lessons: <StarterLesson>[
        StarterLesson(id: 'atomic', titleAr: 'البنية الذرية', titleEn: 'Atomic Structure', cards: <StarterCard>[
          StarterCard(front: 'ما هو العدد الذري؟', back: 'عدد البروتونات في النواة.', tags: <String>['الذرة']),
        ]),
      ],
    ),
    StarterDeck(
      id: 'biology', titleAr: 'البيولوجيا', titleEn: 'Biology',
      descriptionAr: 'الخلية والوراثة', descriptionEn: 'Cells and genetics',
      colorHex: '#3B7A1F', iconKey: 'biotech', tags: <String>['بيولوجيا'], rating: 4.9,
      lessons: <StarterLesson>[
        StarterLesson(id: 'cell', titleAr: 'الخلية', titleEn: 'The Cell', cards: <StarterCard>[
          StarterCard(front: 'ما وظيفة الميتوكوندريا؟', back: 'إنتاج الطاقة ATP.', hint: 'بيت الطاقة.', tags: <String>['الخلية']),
        ]),
      ],
    ),
    StarterDeck(
      id: 'history_of_medicine', titleAr: 'تاريخ الطب', titleEn: 'History of Medicine',
      descriptionAr: 'محطات الطب عبر التاريخ', descriptionEn: 'Milestones in medical history',
      colorHex: '#A65A3A', iconKey: 'history_edu', tags: <String>['تاريخ الطب'], rating: 4.8,
      lessons: <StarterLesson>[
        StarterLesson(id: 'ancient', titleAr: 'الطب القديم', titleEn: 'Ancient Medicine', cards: <StarterCard>[
          StarterCard(front: 'من يُعد أب الطب الغربي؟', back: 'أبقراط.', tags: <String>['أبقراط']),
        ]),
      ],
    ),
    StarterDeck(
      id: 'english_1', titleAr: 'الانكليزية 1', titleEn: 'English 1',
      descriptionAr: 'قواعد ومفردات أكاديمية', descriptionEn: 'Grammar and academic vocabulary',
      colorHex: '#6B5BC9', iconKey: 'translate', tags: <String>['انكليزية'], rating: 4.7,
      lessons: <StarterLesson>[
        StarterLesson(id: 'grammar', titleAr: 'Grammar', titleEn: 'Grammar', cards: <StarterCard>[
          StarterCard(front: 'Complete: She ____ to university.', back: 'goes', tags: <String>['present simple']),
        ]),
      ],
    ),
  ];

  static List<LibraryItem> libraryItems({required bool isArabic}) {
    return decks.map((StarterDeck deck) => LibraryItem(
      id: 'starter-${deck.id}',
      sourceTemplateId: deck.id,
      title: isArabic ? deck.titleAr : deck.titleEn,
      description: isArabic ? deck.descriptionAr : deck.descriptionEn,
      colorHex: deck.colorHex,
      iconKey: deck.iconKey,
      tags: deck.tags,
      cardCount: deck.cardCount,
      subdeckCount: deck.lessons.length,
      authorName: isArabic ? 'فريق بطاقاتي' : 'Bitaqati Team',
      rating: deck.rating,
      isOfficial: true,
      isInstalled: false,
    )).toList(growable: false);
  }

  static StarterDeck? byId(String id) {
    for (final StarterDeck deck in decks) {
      if (deck.id == id) return deck;
    }
    return null;
  }
}

class StarterDeck {
  const StarterDeck({required this.id, required this.titleAr, required this.titleEn, required this.descriptionAr, required this.descriptionEn, required this.colorHex, required this.iconKey, required this.tags, required this.rating, required this.lessons});
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String colorHex;
  final String iconKey;
  final List<String> tags;
  final double rating;
  final List<StarterLesson> lessons;
  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;
  String description(String languageCode) => languageCode == 'ar' ? descriptionAr : descriptionEn;
  int get cardCount => lessons.fold<int>(0, (int value, StarterLesson lesson) => value + lesson.cards.length);
}

class StarterLesson {
  const StarterLesson({required this.id, required this.titleAr, required this.titleEn, required this.cards});
  final String id;
  final String titleAr;
  final String titleEn;
  final List<StarterCard> cards;
  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;
}

class StarterCard {
  const StarterCard({required this.front, required this.back, this.hint = '', this.notes = '', this.tags = const <String>[]});
  final String front;
  final String back;
  final String hint;
  final String notes;
  final List<String> tags;
}
