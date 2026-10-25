import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/subject_chip.dart';
import '../../data/models.dart';

class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends ConsumerState<DecksScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SubjectId? selected = ref.watch(selectedSubjectProvider);
    final String query = _search.text.trim();
    final List<DeckSummary> decks = kMyDecks
        .where((DeckSummary deck) {
          final bool subjectMatches =
              selected == null || deck.subjectId == selected;
          final bool queryMatches =
              query.isEmpty ||
              deck.title.contains(query) ||
              deck.subject.nameAr.contains(query);
          return subjectMatches && queryMatches;
        })
        .toList(growable: false);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 118),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('مجموعاتي', style: context.texts.headlineLarge),
                      const SizedBox(height: 2),
                      Text(
                        'كل ما تدرسه، منظّم في مكان واحد',
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${kMyDecks.length} مجموعات',
                    style: context.texts.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث في المجموعات والبطاقات',
                prefixIcon: const Icon(CupertinoIcons.search, size: 19),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(CupertinoIcons.xmark_circle_fill),
                        iconSize: 18,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SubjectFilterBar(
            selected: selected,
            onChanged: (SubjectId? value) {
              ref.read(selectedSubjectProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 18),
          if (decks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                children: <Widget>[
                  Icon(
                    CupertinoIcons.search,
                    size: 42,
                    color: context.texts.bodySmall?.color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد نتائج مطابقة',
                    style: context.texts.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'جرّب مادة أخرى أو كلمة بحث مختلفة.',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            )
          else
            for (final DeckSummary deck in decks)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
                child: DeckCard(
                  deck: deck,
                  onTap: () => context.push('/deck/${deck.id}'),
                ),
              ),
        ],
      ),
    );
  }
}
