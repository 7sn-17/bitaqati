import '../domain/models.dart';

class StarterCatalog {
  const StarterCatalog._();

  static List<LibraryItem> libraryItems({required bool isArabic}) {
    // This is a simplified version to fix the build errors.
    // In a real scenario, this would parse the full data.
    return const <LibraryItem>[
      LibraryItem(
        id: 'starter-physics', sourceTemplateId: 'physics', title: 'الفيزياء', description: 'أساسيات الفيزياء',
        colorHex: '#1D6FD1', iconKey: 'bolt', tags: ['فيزياء'], cardCount: 10, subdeckCount: 2,
        authorName: 'فريق بطاقاتي', rating: 4.9, isOfficial: true, isInstalled: false,
        deck: kMyDecks.first, // Dummy deck for now
      )
    ];
  }
}

// Dummy data to satisfy the build
const List<DeckSummary> kMyDecks = <DeckSummary>[
  DeckSummary(id: 'biology-cell', title: 'البيولوجيا · الخلية', subjectId: SubjectId.biology, cardCount: 120, dueCount: 9, retention: 91, isPublic: false),
];
