import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext context) => const _CreateSheet(),
  );
}

class _CreateSheet extends StatelessWidget {
  const _CreateSheet();

  @override
  Widget build(BuildContext context) {
    final Color surface = context.isDark ? AppColors.darkSurface : Colors.white;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'ماذا تريد أن تنشئ؟',
                      style: context.texts.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Option(
                icon: CupertinoIcons.rectangle_stack,
                title: 'مجموعة جديدة',
                subtitle: 'نظّم بطاقاتك حسب المادة والفصل',
                onTap: () => _comingSoon(context, 'إنشاء مجموعة جديدة'),
              ),
              _Option(
                icon: CupertinoIcons.doc_text,
                title: 'بطاقة جديدة',
                subtitle: 'أساسية، إخفاء كلمة، اختيار، أو صورة',
                onTap: () => _comingSoon(context, 'محرّر البطاقات'),
              ),
              _Option(
                icon: CupertinoIcons.text_alignleft,
                title: 'استيراد نص',
                subtitle: 'الصق نصك وحوّل كل سطر إلى بطاقة',
                onTap: () => _comingSoon(context, 'الاستيراد الذكي'),
              ),
              _Option(
                icon: CupertinoIcons.sparkles,
                title: 'إنشاء بالذكاء الاصطناعي',
                subtitle: 'من ملف أو صورة أو نص',
                accent: true,
                onTap: () => _comingSoon(context, 'التوليد بالذكاء الاصطناعي'),
              ),
              _Option(
                icon: CupertinoIcons.photo,
                title: 'تغطية صورة',
                subtitle: 'حوّل أجزاء الصورة إلى بطاقات اختبار',
                onTap: () => _comingSoon(context, 'محرّر تغطية الصورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature سيُفعّل في المرحلة القادمة.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final Color tile = accent
        ? (context.isDark ? AppColors.accent : AppColors.accentSoft)
        : context.colors.surfaceContainerHighest;
    final Color foreground = accent
        ? (context.isDark ? AppColors.primary : AppColors.primary)
        : context.colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: context.texts.titleMedium),
                    const SizedBox(height: 1),
                    Text(subtitle, style: context.texts.bodySmall),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_back,
                size: 18,
                color: context.texts.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
