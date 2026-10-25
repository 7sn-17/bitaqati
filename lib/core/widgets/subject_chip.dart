import 'package:flutter/material.dart';
import '../../domain/models.dart';

class SubjectChip extends StatelessWidget {
  const SubjectChip({super.key, required this.subjectId, this.isSelected = false, this.onTap});
  final SubjectId? subjectId;
  final bool isSelected;
  final ValueChanged<SubjectId?>? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subject = subjectId != null ? subjectById(subjectId!) : null;
    final label = subject?.nameAr ?? 'الكل';
    final color = subject?.color ?? (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTap: () => onTap?.call(subjectId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
