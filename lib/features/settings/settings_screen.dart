import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surface_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool notifications = ref.watch(notificationsEnabledProvider);
    final bool isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && context.isDark);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
              child: Row(
                children: <Widget>[
                  _RoundButton(
                    icon: CupertinoIcons.chevron_forward,
                    onTap: () => context.pop(),
                    label: 'رجوع',
                  ),
                  const SizedBox(width: 8),
                  Text('الإعدادات', style: context.texts.headlineMedium),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SurfaceCard(
                color: context.isDark
                    ? AppColors.darkSurfaceHigh
                    : AppColors.primary,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'ب',
                        style: TextStyle(
                          fontFamily: 'ReadexPro',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '7sn',
                            style: TextStyle(
                              fontFamily: 'ReadexPro',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'طالب · الخطة المجانية',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.pencil,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
            const _SectionLabel('الحساب'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.mail,
                  title: 'البريد الإلكتروني',
                  subtitle: 'غير مرتبط بعد',
                  onTap: () => _comingSoon(context, 'ربط الحساب'),
                ),
                _Row(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  title: 'المزامنة السحابية',
                  subtitle: 'ستُفعّل مع المرحلة الثانية',
                  onTap: () => _comingSoon(context, 'المزامنة'),
                ),
                _Row(
                  icon: CupertinoIcons.archivebox,
                  title: 'النسخ الاحتياطي',
                  subtitle: 'تصدير بياناتك في أي وقت',
                  onTap: () => _comingSoon(context, 'النسخ الاحتياطي'),
                ),
              ],
            ),
            const _SectionLabel('المظهر'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.moon,
                  title: 'الوضع الداكن',
                  subtitle: 'مريح للعين في الإضاءة المنخفضة',
                  trailing: Switch.adaptive(
                    value: isDark,
                    onChanged: (_) {
                      ref.read(themeModeProvider.notifier).toggleDark();
                    },
                  ),
                ),
                _Row(
                  icon: CupertinoIcons.globe,
                  title: 'لغة التطبيق',
                  subtitle: 'العربية',
                  onTap: () => _comingSoon(context, 'تغيير اللغة'),
                ),
              ],
            ),
            const _SectionLabel('الإشعارات'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.bell,
                  title: 'تذكير المراجعة اليومي',
                  subtitle: 'نذكّرك في الوقت المناسب',
                  trailing: Switch.adaptive(
                    value: notifications,
                    onChanged: (bool value) {
                      ref.read(notificationsEnabledProvider.notifier).state =
                          value;
                      ref
                          .read(sharedPreferencesProvider)
                          .setBool('notifications', value);
                    },
                  ),
                ),
                _Row(
                  icon: CupertinoIcons.time,
                  title: 'وقت التذكير',
                  subtitle: '8:00 مساءً',
                  onTap: () => _comingSoon(context, 'تعديل وقت التذكير'),
                ),
              ],
            ),
            const _SectionLabel('الدراسة'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.add,
                  title: 'بطاقات جديدة يومياً',
                  subtitle: '10 بطاقات',
                  onTap: () => _comingSoon(context, 'إعدادات الدراسة'),
                ),
                _Row(
                  icon: CupertinoIcons.arrow_counterclockwise,
                  title: 'نسبة التذكر المطلوبة',
                  subtitle: '90%',
                  onTap: () => _comingSoon(context, 'إعدادات الدراسة'),
                ),
                _Row(
                  icon: CupertinoIcons.clock,
                  title: 'المنطقة الزمنية',
                  subtitle: 'تلقائية',
                  onTap: () => _comingSoon(context, 'المنطقة الزمنية'),
                ),
              ],
            ),
            const _SectionLabel('البيانات'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.square_arrow_up,
                  title: 'تصدير البيانات',
                  subtitle: 'JSON · CSV',
                  onTap: () => _comingSoon(context, 'تصدير البيانات'),
                ),
                _Row(
                  icon: CupertinoIcons.square_arrow_down,
                  title: 'استيراد البيانات',
                  subtitle: 'من ملف أو نسخة احتياطية',
                  onTap: () => _comingSoon(context, 'استيراد البيانات'),
                ),
                _Row(
                  icon: CupertinoIcons.trash,
                  title: 'مسح جميع البيانات',
                  subtitle: 'لا يمكن التراجع',
                  danger: true,
                  onTap: () => _comingSoon(context, 'مسح البيانات'),
                ),
              ],
            ),
            const _SectionLabel('عن التطبيق'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.info_circle,
                  title: 'الإصدار',
                  subtitle: AppConfig.appVersion,
                ),
                _Row(
                  icon: CupertinoIcons.doc_text,
                  title: 'سياسة الخصوصية',
                  onTap: () => _comingSoon(context, 'سياسة الخصوصية'),
                ),
                _Row(
                  icon: CupertinoIcons.question_circle,
                  title: 'المساعدة والدعم',
                  onTap: () => _comingSoon(context, 'المساعدة'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton(
                onPressed: () => _comingSoon(context, 'تسجيل الخروج'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: const Text('تسجيل الخروج'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'صُنع بشغف للطلاب العرب',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature سيُفعّل قريباً.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      child: Text(
        label,
        style: context.texts.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.texts.bodySmall?.color,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: context.colors.surfaceContainerHighest,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < children.length; index++) ...<Widget>[
                children[index],
                if (index != children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 54),
                    child: Divider(
                      height: 1,
                      color: context.colors.outlineVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color ink = danger ? AppColors.danger : context.colors.onSurface;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: danger
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : context.isDark
                  ? AppColors.darkSurfaceHigh
                  : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: danger ? AppColors.danger : context.colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.texts.titleSmall?.copyWith(color: ink),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              CupertinoIcons.chevron_back,
              size: 17,
              color: context.texts.bodySmall?.color,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;

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
