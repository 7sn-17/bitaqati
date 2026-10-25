import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../i18n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_surface.dart';

IconData deckIcon(String key) {
  return switch (key) {
    'bolt' => Icons.bolt_rounded,
    'science' => Icons.science_rounded,
    'biotech' => Icons.biotech_rounded,
    'history_edu' => Icons.history_edu_rounded,
    'translate' => Icons.translate_rounded,
    'menu_book' => Icons.menu_book_rounded,
    'psychology' => Icons.psychology_rounded,
    'calculate' => Icons.calculate_rounded,
    'code' => Icons.code_rounded,
    'palette' => Icons.palette_rounded,
    'public' => Icons.public_rounded,
    'folder' => Icons.folder_rounded,
    'school' => Icons.school_rounded,
    'medical' => Icons.medical_services_rounded,
    'gavel' => Icons.gavel_rounded,
    _ => Icons.layers_rounded,
  };
}

class DeckTile extends StatelessWidget {
  const DeckTile({
    required this.deck,
    super.key,
    this.onTap,
    this.onLongPress,
    this.showProgress = true,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final DeckSummary deck;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showProgress;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final Color accent = AppColors.fromHex(deck.colorHex);
    final String subtitle = deck.subdeckCount > 0
        ? '${strings.cardsCount(deck.cardCount)} · ${strings.subdecksCount(deck.subdeckCount)}'
        : strings.cardsCount(deck.cardCount);
    return SurfaceCard(
      onTap: onTap,
      onLongPress: onLongPress,
      margin: margin,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          AppIconBadge(
            icon: deckIcon(deck.iconKey),
            color: accent,
            size: 50,
            radius: 15,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        deck.title,
                        style: context.texts.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (deck.isShared) ...<Widget>[
                      const SizedBox(width: 6),
                      PrivacyBadge(
                        label: privacyLabel(context, deck.privacy),
                        color: deck.isPublic
                            ? context.colors.secondary
                            : context.colors.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.texts.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showProgress && deck.cardCount > 0) ...<Widget>[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: deck.progress,
                      minHeight: 4,
                      backgroundColor: context.colors.surfaceContainerHighest,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              _DueColumn(
                dueCount: deck.dueCount,
                newCount: deck.newCount,
                cardCount: deck.cardCount,
                accent: accent,
              ),
        ],
      ),
    );
  }
}

class _DueColumn extends StatelessWidget {
  const _DueColumn({
    required this.dueCount,
    required this.newCount,
    required this.cardCount,
    required this.accent,
  });

  final int dueCount;
  final int newCount;
  final int cardCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    if (cardCount == 0) {
      return Icon(
        Icons.add_circle_outline_rounded,
        color: context.colors.onSurfaceVariant,
        size: 22,
      );
    }
    if (dueCount > 0) {
      return Container(
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: context.isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$dueCount',
              style: context.texts.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              strings.due,
              style: context.texts.labelSmall?.copyWith(color: accent),
            ),
          ],
        ),
      );
    }
    return Icon(
      Icons.check_circle_rounded,
      color: context.colors.secondary.withValues(alpha: 0.7),
      size: 22,
    );
  }
}

class ChildDeckRow extends StatelessWidget {
  const ChildDeckRow({
    required this.deck,
    super.key,
    this.onTap,
    this.onLongPress,
  });

  final DeckSummary deck;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final Color accent = AppColors.fromHex(deck.colorHex);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: <Widget>[
              AppIconBadge(
                icon: deckIcon(deck.iconKey),
                color: accent,
                size: 38,
                radius: 11,
                iconSize: 18,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      deck.title,
                      style: context.texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deck.subdeckCount > 0
                          ? '${strings.cardsCount(deck.cardCount)} · ${strings.subdecksCount(deck.subdeckCount)}'
                          : strings.cardsCount(deck.cardCount),
                      style: context.texts.labelSmall,
                    ),
                  ],
                ),
              ),
              if (deck.dueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${deck.dueCount}',
                    style: context.texts.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeckSummaryCard extends StatelessWidget {
  const DeckSummaryCard({
    required this.deck,
    super.key,
    this.onTap,
    this.label,
  });

  final DeckSummary deck;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.fromHex(deck.colorHex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: context.colors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppIconBadge(
                  icon: deckIcon(deck.iconKey),
                  color: accent,
                  size: 42,
                  radius: 13,
                ),
                const Spacer(),
                Text(
                  label ?? context.strings.dueCount(deck.dueCount),
                  style: context.texts.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              deck.title,
              style: context.texts.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              context.strings.cardsCount(deck.cardCount),
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: deck.progress,
                minHeight: 5,
                backgroundColor: context.colors.surfaceContainerHighest,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
