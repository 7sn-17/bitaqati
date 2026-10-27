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
import '../../data/sync_providers.dart';
import '../../data/sync_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final User? user = ref.watch(currentUserProvider).valueOrNull;
    final bool guestMode = ref.watch(guestModeProvider);
    final bool guest = user == null && guestMode;
    final String? avatarUrl = userAvatarUrl(user);
    final String displayName =
        userFirstName(user) ?? (guest ? 'زائر' : 'بطاقاتي');
    final String accountSubtitle =
        user?.email ??
        (guest ? 'وضع الزائر · للتصفح فقط' : 'غير مسجل الدخول');
    final bool isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && context.isDark);
    final bool notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final int newLimit = ref.watch(dailyNewLimitProvider);
    final int reviewLimit = ref.watch(dailyReviewLimitProvider);
    final SyncState sync = ref.watch(syncControllerProvider);
    final bool signedIn = user != null;

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
                  onTap: user == null ? () => _goToLogin(ref) : null,
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
                  icon: CupertinoIcons.bell,
                  title: 'التذكير اليومي',
                  subtitle: 'تنبيه واحد في اليوم لمراجعة بطاقاتك',
                  trailing: Switch.adaptive(
                    value: notificationsEnabled,
                    onChanged: (bool value) {
                      ref
                          .read(notificationsEnabledProvider.notifier)
                          .state = value;
                    },
                  ),
                ),
              ],
            ),
            const _SectionLabel('أهداف المراجعة'),
            _Group(
              children: <Widget>[
                _StepperRow(
                  icon: CupertinoIcons.sparkles,
                  title: 'بطاقات جديدة في الجلسة',
                  subtitle: 'كم بطاقة جديدة تُقدَّم لك في كل جلسة دراسة',
                  value: newLimit,
                  onIncrease: newLimit >= 200
                      ? null
                      : () => ref
                            .read(dailyNewLimitProvider.notifier)
                            .increment(),
                  onDecrease: newLimit <= 0
                      ? null
                      : () => ref
                            .read(dailyNewLimitProvider.notifier)
                            .decrement(),
                ),
                _StepperRow(
                  icon: CupertinoIcons.repeat,
                  title: 'بطاقات المراجعة في الجلسة',
                  subtitle: 'حد أقصى للمراجعات في الجلسة الواحدة',
                  value: reviewLimit,
                  onIncrease: reviewLimit >= 1000
                      ? null
                      : () => ref
                            .read(dailyReviewLimitProvider.notifier)
                            .increment(),
                  onDecrease: reviewLimit <= 20
                      ? null
                      : () => ref
                            .read(dailyReviewLimitProvider.notifier)
                            .decrement(),
                ),
              ],
            ),
            const _SectionLabel('المزامنة'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  title: sync.running ? 'جارٍ المزامنة…' : 'مزامنة الآن',
                  subtitle: _syncSubtitle(sync.report, signedIn),
                  trailing: sync.running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : null,
                  onTap: signedIn && !sync.running
                      ? () async {
                          await ref
                              .read(syncControllerProvider.notifier)
                              .syncNow();
                          final SyncReport? report =
                              ref.read(syncControllerProvider).report;
                          if (!context.mounted || report == null) {
                            return;
                          }
                          showAppMessage(
                            context,
                            report.error ??
                                (report.idle
                                    ? 'كل شيء محدّث بالفعل.'
                                    : 'تمت المزامنة: '
                                          '${report.pushed} رفع، '
                                          '${report.pulled} تنزيل.'),
                            kind: report.ok
                                ? AppMessageKind.success
                                : AppMessageKind.error,
                          );
                        }
                      : null,
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
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: guest
                  ? FilledButton.icon(
                      onPressed: () => _goToLogin(ref),
                      icon: const Icon(CupertinoIcons.person, size: 17),
                      label: const Text('تسجيل الدخول بحساب Google'),
                    )
                  : OutlinedButton(
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

  /// One line explaining where the last sync left off.
  String _syncSubtitle(SyncReport? report, bool signedIn) {
    if (!signedIn) {
      return 'سجّل الدخول لمزامنة بطاقاتك بين أجهزتك';
    }
    if (report == null) {
      return 'لم تتم مزامنة بعد';
    }
    if (report.error != null) {
      return report.error!;
    }
    if (report.idle) {
      return 'كل شيء محدّث';
    }
    return 'رفع ${report.pushed} · نزّل ${report.pulled}';
  }

  /// Leaves guest mode. The router then shows the login screen, where the
  /// user can link a Google account without losing local data.
  Future<void> _goToLogin(WidgetRef ref) async {
    await ref.read(guestModeProvider.notifier).exit();
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.colors.onSurface;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.isDark
                  ? AppColors.darkSurfaceHigh
                  : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: context.colors.primary,
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

/// A row with − and + buttons, used for the numeric daily goals.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onIncrease,
    required this.onDecrease,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            icon: CupertinoIcons.minus,
            onTap: onDecrease,
            label: 'تقليل',
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepButton(
            icon: CupertinoIcons.plus,
            onTap: onIncrease,
            label: 'زيادة',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: enabled
                ? context.softAccent
                : context.raisedSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 15,
            color: enabled ? context.brandInk : context.muted,
          ),
        ),
      ),
    );
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
