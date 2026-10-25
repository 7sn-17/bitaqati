import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SubjectChip extends StatelessWidget {
  const SubjectChip({
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

class SubjectFilterBar extends StatelessWidget {
  const SubjectFilterBar({
    required this.selected,
    required this.onChanged,
    this.includeAll = true,
    super.key,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: <Widget>[
          if (includeAll) ...<Widget>[
            SubjectChip(
              label: 'الكل',
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            const SizedBox(width: 8),
          ],
          for (final Subject subject in kSubjects) ...<Widget>[
            SubjectChip(
              label: subject.nameAr,
              color: subject.color,
              selected: selected == subject.id,
              onTap: () => onChanged(subject.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
