import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_surface.dart';
import '../../core/widgets/deck_card.dart';
import '../../domain/models.dart';
import '../common/catalog_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CatalogView(
      builder: (BuildContext context, Catalog catalog) {
        final AppStrings strings = context.strings;
        final DashboardStats stats = catalog.dashboard;
        final String? selectedTag = ref.watch(selectedTagProvider);
        final String sort = ref.watch(deckSortProvider);
        final List<DeckNode> roots = List<DeckNode>.of(catalog.roots);
        if (selectedTag != null) {
          roots.removeWhere(
            (DeckNode node) => !node.summary.tags.contains(selectedTag),
          );
        }
        roots.sort((DeckNode a, DeckNode b) {
          switch (sort) {
            case 'az':
              return a.summary.title.compareTo(b.summary.title);
            case 'new':
              return b.summary.createdAt.compareTo(a.summary.createdAt);
            default:
              final int byDue = b.summary.dueCount.compareTo(
                a.summary.dueCount,
              );
              return byDue != 0
                  ? byDue
                  : a.summary.title.compareTo(b.summary.title);
          }
        });
        final List<DeckNode> dueRoots =
            catalog.roots
                .where((DeckNode node) => node.summary.dueCount > 0)
                .toList(growable: false)
              ..sort(
                (DeckNode a, DeckNode b) =>
                    b.summary.dueCount.compareTo(a.summary.dueCount),
              );
        final DeckNode? continueDeck = dueRoots.isEmpty
            ? (catalog.roots.isEmpty ? null : catalog.roots.first)
            : dueRoots.first;
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
                _HomeHeader(
                  displayName: catalog.displayName,
                  avatarUrl: ref.watch(authUserProvider).valueOrNull?.avatarUrl,
                ),
              ),
              const SizedBox(height: 20),
              maxWidth(
                _DueHero(
                  stats: stats,
                  onReview: continueDeck == null
                      ? null
                      : () => context.go(
                          '/deck/${continueDeck.summary.id}/study',
                        ),
                  onBrowse: () => context.go('/library'),
                ),
              ),
              const SizedBox(height: 14),
              maxWidth(
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatPill(
                        icon: Icons.local_fire_department_rounded,
                        value: '${stats.streak}',
                        label: strings.streakDays,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatPill(
                        icon: Icons.done_all_rounded,
                        value: '${stats.reviewsToday}',
                        label: strings.todayReviews,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatPill(
                        icon: Icons.track_changes_rounded,
                        value: '${stats.retention.round()}%',
                        label: strings.retention,
                        color: AppColors.lavender,
                      ),
                    ),
                  ],
                ),
              ),
              if (dueRoots.isNotEmpty) ...<Widget>[
                maxWidth(
                  SectionHeader(
                    title: strings.continueStudying,
                    icon: Icons.play_circle_outline_rounded,
                    padding: const EdgeInsets.fromLTRB(0, 26, 0, 12),
                  ),
                ),
                SizedBox(
                  height: 166,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: dueRoots.length > 6 ? 6 : dueRoots.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final DeckNode node = dueRoots[index];
                      return DeckSummaryCard(
                        deck: node.summary,
                        label: strings.dueCount(node.summary.dueCount),
                        onTap: () => context.go('/deck/${node.summary.id}'),
                      );
                    },
                  ),
                ),
              ],
              if (catalog.popularTags.isNotEmpty) ...<Widget>[
                maxWidth(
                  SectionHeader(
                    title: strings.tagsFilter,
                    actionLabel: selectedTag == null
                        ? null
                        : strings.clearFilters,
                    onAction: selectedTag == null
                        ? null
                        : () => ref.read(selectedTagProvider.notifier).state =
                              null,
                    padding: const EdgeInsets.fromLTRB(0, 26, 0, 10),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AppChip(
                          label: strings.all,
                          icon: Icons.grid_view_rounded,
                          selected: selectedTag == null,
                          onTap: () =>
                              ref.read(selectedTagProvider.notifier).state =
                                  null,
                        ),
                      ),
                      ...catalog.popularTags.map(
                        (String tag) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AppChip(
                            label: tag,
                            selected: selectedTag == tag,
                            onTap: () =>
                                ref.read(selectedTagProvider.notifier).state =
                                    selectedTag == tag ? null : tag,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              maxWidth(
                SectionHeader(
                  title: strings.yourDecks,
                  actionLabel: strings.add,
                  onAction: () => context.go('/library'),
                  padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
                ),
              ),
              if (roots.isEmpty)
                maxWidth(
                  SurfaceCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.create_new_folder_outlined,
                      title: strings.noDecksTitle,
                      body: strings.noDecksBody,
                      action: FilledButton.icon(
                        onPressed: () => context.go('/library'),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(strings.createDeck),
                      ),
                    ),
                  ),
                )
              else
                ...roots.map(
                  (DeckNode node) => maxWidth(
                    DeckTile(
                      deck: node.summary,
                      onTap: () => context.go('/deck/${node.summary.id}'),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final String name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : strings.appName;
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            Icons.style_rounded,
            color: context.colors.onPrimary,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(strings.welcomeBack, style: context.texts.labelMedium),
              const SizedBox(height: 2),
              Text(
                name,
                style: context.texts.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.go('/search'),
          icon: const Icon(Icons.search_rounded),
          tooltip: strings.search,
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: CircleAvatar(
            radius: 21,
            backgroundColor: context.colors.surfaceContainerHigh,
            backgroundImage: avatarUrl == null || avatarUrl!.isEmpty
                ? null
                : NetworkImage(avatarUrl!),
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(
                    Icons.person_outline_rounded,
                    color: context.colors.onSurface,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _DueHero extends StatelessWidget {
  const _DueHero({required this.stats, this.onReview, this.onBrowse});

  final DashboardStats stats;
  final VoidCallback? onReview;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final bool isDark = context.isDark;
    final bool hasDue = stats.dueCount > 0;
    final Color background = isDark
        ? const Color(0xFF1B2418)
        : AppColors.forest;
    final Color foreground = isDark ? AppColors.lime : AppColors.lime;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? AppColors.lime.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasDue ? strings.dueToday : strings.allCaughtUp,
                    style: context.texts.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasDue ? '${stats.dueCount}' : '0',
                  style: context.texts.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hasDue ? strings.cardsDueNow : strings.noDueCardsBody,
                  style: context.texts.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: onReview,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.forest,
                          minimumSize: const Size(0, 46),
                        ),
                        child: Text(
                          hasDue ? strings.reviewNow : strings.study,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton(
                      onPressed: onBrowse,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(46, 46),
                      ),
                      icon: const Icon(Icons.explore_outlined),
                      tooltip: strings.library,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ProgressRing(
            value: stats.totalCards == 0
                ? 0
                : (stats.totalCards - stats.dueCount) / stats.totalCards,
            size: 92,
            strokeWidth: 9,
            color: AppColors.lime,
            label: stats.totalCards == 0
                ? '—'
                : '${stats.totalCards - stats.dueCount}/${stats.totalCards}',
          ),
        ],
      ),
    );
  }
}
