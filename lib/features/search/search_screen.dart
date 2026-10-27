import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/deck_card.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _query.trim();
    final List<DeckNode> all = ref.watch(allDecksProvider);
    final List<DeckNode> decks = query.isEmpty
        ? all
        : all
              .where(
                (DeckNode deck) =>
                    deck.title.contains(query) ||
                    deck.tags.any((String tag) => tag.contains(query)),
              )
              .toList(growable: false);
    final List<ReviewCard> cards =
        ref.watch(searchCardsProvider(query)).valueOrNull ??
        const <ReviewCard>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  _RoundButton(
                    icon: CupertinoIcons.chevron_forward,
                    label: 'رجوع',
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (String value) =>
                          setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن مجموعة أو بطاقة',
                        prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                ),
                                iconSize: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                query.isEmpty ? 'اقتراحات سريعة' : 'المجموعات',
                style: context.texts.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            if (decks.isEmpty && cards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: <Widget>[
                    Icon(
                      CupertinoIcons.search,
                      size: 42,
                      color: context.texts.bodySmall?.color,
                    ),
                    const SizedBox(height: 10),
                    Text('لا توجد نتائج', style: context.texts.titleMedium),
                  ],
                ),
              )
            else ...<Widget>[
              for (final DeckNode deck in decks.take(4))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
                  child: DeckCard(
                    deck: deck,
                    onTap: () => context.push('/deck/${deck.id}'),
                  ),
                ),
              if (cards.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('البطاقات', style: context.texts.titleLarge),
                ),
                const SizedBox(height: 8),
                for (final ReviewCard card in cards.take(6))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Material(
                      color: context.colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/deck/${card.deckId}'),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                CupertinoIcons.doc_text,
                                size: 20,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      card.front,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      card.back,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: context.colors.onSurface),
        ),
      ),
    );
  }
}
