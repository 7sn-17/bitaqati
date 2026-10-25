import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_surface.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/editor_sheets.dart';
import '../../data/starter_content.dart';
import '../../domain/models.dart';
import '../common/catalog_view.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _createDeck(BuildContext context, WidgetRef ref) async {
    final DeckDraft? draft = await showDeckEditor(context);
    if (draft == null || !context.mounted) {
      return;
    }
    try {
      final String id = await ref
          .read(contentRepositoryProvider)
          .createDeck(
            title: draft.title,
            description: draft.description,
            colorHex: draft.colorHex,
            iconKey: draft.iconKey,
            tags: draft.tags,
            privacy: draft.privacy,
          );
      ref.invalidate(catalogProvider);
      if (context.mounted) {
        showAppSnack(context, context.strings.deckCreated);
        context.go('/deck/$id');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnack(context, error.toString(), error: true);
      }
    }
  }

  Future<void> _install(
    BuildContext context,
    WidgetRef ref,
    LibraryItem item,
  ) async {
    final String? templateId = item.sourceTemplateId;
    if (templateId == null) {
      return;
    }
    try {
      final String id = await ref
          .read(contentRepositoryProvider)
          .installStarter(
            templateId,
            languageCode: ref.read(localeProvider).languageCode,
          );
      ref.invalidate(catalogProvider);
      if (context.mounted) {
        showAppSnack(context, context.strings.installedSuccess);
        context.go('/deck/$id');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnack(context, error.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = context.strings;
    final int segment = ref.watch(librarySegmentProvider);
    return CatalogView(
      builder: (BuildContext context, Catalog catalog) {
        final bool isArabic = ref.watch(localeProvider).languageCode == 'ar';
        final List<LibraryItem> official = StarterCatalog.libraryItems(
          isArabic: isArabic,
        );
        final Set<String> installedTemplates = catalog.allDecks
            .map((DeckNode node) => node.summary.sourceTemplateId)
            .whereType<String>()
            .toSet();
        final List<LibraryItem> community = catalog.communityLibraryItems;
        return RefreshIndicator(
          onRefresh: () => refreshCatalog(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 12,
              20,
              132,
            ),
            children: <Widget>[
              maxWidth(
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.libraryTitle,
                            style: context.texts.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            segment == 0
                                ? strings.officialLibraryNote
                                : strings.publicLibraryNote,
                            style: context.texts.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _createDeck(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      tooltip: strings.createDeck,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              maxWidth(
                Row(
                  children: <Widget>[
                    AppChip(
                      label: strings.official,
                      icon: Icons.verified_rounded,
                      selected: segment == 0,
                      onTap: () =>
                          ref.read(librarySegmentProvider.notifier).state = 0,
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: strings.community,
                      icon: Icons.groups_rounded,
                      selected: segment == 1,
                      onTap: () =>
                          ref.read(librarySegmentProvider.notifier).state = 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (segment == 0)
                ...official.map(
                  (LibraryItem item) => maxWidth(
                    _LibraryCard(
                      item: item,
                      isInstalled: installedTemplates.contains(item.title),
                      actionLabel: strings.install,
                      onAction: () => _install(context, ref, item),
                    ),
                  ),
                )
              else if (community.isEmpty)
                maxWidth(
                  SurfaceCard(
                    child: EmptyState(
                      icon: Icons.public_off_rounded,
                      title: strings.noPublicDecks,
                      body: strings.noPublicDecksBody,
                    ),
                  ),
                )
              else
                ...community.map(
                  (LibraryItem item) => maxWidth(
                    _LibraryCard(
                      item: item,
                      isInstalled: true,
                      actionLabel: strings.installed,
                      onAction: item.deckId == null
                          ? null
                          : () => context.go('/deck/${item.deckId}'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.item,
    required this.isInstalled,
    required this.actionLabel,
    this.onAction,
  });

  final LibraryItem item;
  final bool isInstalled;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final Color accent = AppColors.fromHex(item.colorHex);
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppIconBadge(
                icon: deckIcon(item.iconKey),
                color: accent,
                size: 52,
                radius: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: context.texts.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isOfficial)
                          PrivacyBadge(
                            label: strings.official,
                            color: AppColors.mint,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.authorName.isEmpty ? strings.you : item.authorName,
                      style: context.texts.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.style_rounded,
                          size: 13,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strings.cardsCount(item.cardCount),
                          style: context.texts.labelSmall,
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.layers_rounded,
                          size: 13,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strings.subdecksCount(item.subdeckCount),
                          style: context.texts.labelSmall,
                        ),
                        if (item.rating > 0) ...<Widget>[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: context.texts.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              item.description,
              style: context.texts.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (item.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            AppTagWrap(tags: item.tags, maxTags: 4),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              onPressed: onAction,
              icon: Icon(
                isInstalled
                    ? Icons.check_rounded
                    : Icons.download_rounded,
                size: 18,
              ),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: accent.withValues(alpha: 0.14),
                foregroundColor: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
