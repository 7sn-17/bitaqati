import '../domain/models.dart';

class StarterCatalog {
  const StarterCatalog._();

  static List<LibraryItem> libraryItems({required bool isArabic}) {
    return <LibraryItem>[
      LibraryItem(
        id: 'starter-physics', sourceTemplateId: 'physics', title: 'الفيزياء', description: 'أساسيات الفيزياء',
        colorHex: '#1D6FD1', iconKey: 'bolt', tags: const ['فيزياء'], cardCount: 10, subdeckCount: 2,
        authorName: 'فريق بطاقاتي', rating: 4.9, isOfficial: true, isInstalled: false,
        deck: kMyDecks.first,
      )
    ];
  }
}
