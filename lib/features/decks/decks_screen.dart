import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tag_filter_bar.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';

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
    final String? selected = ref.watch(selectedTagProvider);
    final String query = _search.text.trim();
    final List<DeckNode> allDecks = ref.watch(allDecksProvider);
    final List<DeckNode> decks = allDecks
        .where((DeckNode deck) {
          final bool tagMatches = selected == null || deck.hasTag(selected);
          final bool queryMatches =
              query.isEmpty ||
              deck.title.contains(query) ||
              deck.tags.any((String tag) => tag.contains(query));
          return tagMatches && queryMatches;
        })
        .toList(growable: false);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverList.list(
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
                    '${allDecks.length} مجموعات',
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
          TagFilterBar(
            tags: ref.watch(deckTagsProvider),
            selected: selected,
            onChanged: (String? value) {
              ref.read(selectedTagProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 18),
            ],
          ),
          if (decks.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: allDecks.isEmpty
                    ? CupertinoIcons.rectangle_stack
                    : CupertinoIcons.search,
                title: allDecks.isEmpty
                    ? 'لا توجد مجموعات بعد'
                    : 'لا توجد نتائج مطابقة',
                message: allDecks.isEmpty
                    ? 'أنشئ أول مجموعة من زر + في الأسفل.'
                    : 'جرّب وسماً آخر أو كلمة بحث مختلفة.',
              ),
            )
          else
            // Built lazily: a deck list that grows to a few hundred entries
            // should cost the same to open as one with ten.
            SliverList.builder(
              itemCount: decks.length,
              itemBuilder: (BuildContext context, int index) {
                final DeckNode deck = decks[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
                  child: DeckCard(
                    deck: deck,
                    onTap: () => context.push('/deck/${deck.id}'),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 118)),
        ],
      ),
    );
  }
}
