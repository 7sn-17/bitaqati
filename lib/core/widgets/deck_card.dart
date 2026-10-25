import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class DeckCard extends StatelessWidget {
  const DeckCard({
    required this.deck,
    required this.onTap,
    this.showAuthor = false,
    this.trailing,
    super.key,
  });

  final DeckSummary deck;
  final VoidCallback onTap;
  final bool showAuthor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Subject subject = deck.subject;
    final Color tileColor = subject.color;
    final Color surface = context.colors.surfaceContainerHighest;
    final Color onSurface = context.colors.onSurface;
    final Color muted = context.texts.bodySmall?.color ?? AppColors.muted;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: Icon(subject.icon, color: Colors.white, size: 26),
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
                            deck.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      showAuthor && deck.author != null
                          ? '${deck.cardCount} بطاقة · ${deck.author}'
                          : '${deck.cardCount} بطاقة · ${deck.isPublic ? 'عامة' : 'خاصة'} · حفظ ${deck.retention.round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall,
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: deck.progress,
                              minHeight: 5,
                              backgroundColor: context.isDark
                                  ? AppColors.darkLine
                                  : Colors.white,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                tileColor,
                              ),
                            ),
                          ),
                        ),
                        if (deck.dueCount > 0) ...<Widget>[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${deck.dueCount} مستحقة',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ] else ...<Widget>[
                          const SizedBox(width: 10),
                          Text(
                            deck.retention > 0
                                ? 'أُنجزت'
                                : '${deck.rating?.toStringAsFixed(1) ?? '—'} ★',
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
