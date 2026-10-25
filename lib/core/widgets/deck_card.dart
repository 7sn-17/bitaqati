import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../theme/app_colors.dart';

class DeckCard extends StatelessWidget {
  const DeckCard({super.key, required this.deck, this.onTap});
  final DeckSummary deck;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DeckSummaryCard(deck: deck, onTap: onTap);
  }
}

class DeckSummaryCard extends StatelessWidget {
  const DeckSummaryCard({super.key, required this.deck, this.onTap, this.label});
  final DeckSummary deck;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = deck.color;

    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppColors.darkLine : AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(deck.deckIcon, color: cardColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deck.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${deck.cardCount} cards • ${deck.dueCount} due', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: deck.progress,
                backgroundColor: isDark ? AppColors.darkLine : AppColors.line,
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeckTile extends StatelessWidget {
  const DeckTile({super.key, required this.deck, this.onTap});
  final DeckSummary deck;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DeckSummaryCard(deck: deck, onTap: onTap);
}
