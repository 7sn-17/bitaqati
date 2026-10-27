import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? AppColors.primary;
    final Color background = selected
        ? (context.isDark ? AppColors.accent : accent)
        : context.colors.surfaceContainerHighest;
    final Color foreground = selected
        ? (context.isDark ? AppColors.primary : Colors.white)
        : context.colors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: selected || !context.isDark
                ? null
                : Border.all(color: context.colors.outlineVariant, width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 13,
              height: 1.2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal chips built from the tags the user's decks actually use.
/// Renders nothing until at least one deck has a tag.
class TagFilterBar extends StatelessWidget {
  const TagFilterBar({
    required this.tags,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: <Widget>[
          TagChip(
            label: 'الكل',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          for (final String tag in tags) ...<Widget>[
            TagChip(
              label: tag,
              selected: selected == tag,
              onTap: () => onChanged(tag),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
