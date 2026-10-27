import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_display.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool notifications = ref.watch(notificationsEnabledProvider);
    final Locale locale = ref.watch(languageProvider);
    final User? user = ref.watch(currentUserProvider).valueOrNull;
    final bool guestMode = ref.watch(guestModeProvider);
    final bool guest = user == null && guestMode;
    final String? avatarUrl = userAvatarUrl(user);
    final String displayName =
        userFirstName(user) ?? (guest ? 'زائر' : 'بطاقاتي');
    final String accountSubtitle =
        user?.email ??
        (guest ? 'وضع الزائر · البيانات محلية' : 'غير مسجل الدخول');
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
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: _AccountAvatar(
                        url: avatarUrl,
                        initial: userInitial(user),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'ReadexPro',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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
                  subtitle: user?.email ?? 'غير مرتبط بعد',
                  onTap: user == null
                      ? () => _comingSoon(context, 'ربط الحساب')
                      : null,
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
                  subtitle: locale.languageCode == 'ar' ? 'العربية' : 'English',
                  onTap: () => _pickLanguage(context, ref),
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
                onPressed: () => _signOut(context, ref),
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
    showAppMessage(
      context,
      'سنضيف $feature في تحديث قادم.',
      kind: AppMessageKind.info,
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final String current = ref.read(languageProvider).languageCode;
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Text(
                    'ع',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: const Text('العربية'),
                trailing: current == 'ar'
                    ? Icon(
                        CupertinoIcons.checkmark_alt,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheet).pop('ar'),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Text(
                    'EN',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: const Text('English'),
                trailing: current == 'en'
                    ? Icon(
                        CupertinoIcons.checkmark_alt,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheet).pop('en'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                child: Text(
                  'الواجهة تتغيّر الآن، وترجمة النصوص الكاملة قادمة في تحديث '
                  'لاحق.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall?.copyWith(height: 1.7),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || chosen == current || !context.mounted) {
      return;
    }
    await ref.read(languageProvider.notifier).setLanguage(chosen);
    if (context.mounted) {
      showAppMessage(
        context,
        chosen == 'ar' ? 'تم تغيير اللغة إلى العربية' : 'Language changed',
      );
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('ستبقى بطاقاتك محفوظة على هذا الجهاز.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AuthService auth = ref.read(authServiceProvider);
    final GuestModeNotifier guestMode = ref.read(guestModeProvider.notifier);
    showAppMessage(context, 'تم تسجيل الخروج.');
    await guestMode.exit();
    await auth.signOut();
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.url, required this.initial});

  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(
      initial,
      style: const TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
    if (url == null) {
      return label;
    }
    return Image.network(
      url!,
      width: 54,
      height: 54,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return label;
      },
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
