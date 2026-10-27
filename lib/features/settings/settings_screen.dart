import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/notifications/reminder_providers.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/updates/update_providers.dart';
import '../../core/updates/update_service.dart';
import '../../core/user_display.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/auth_service.dart';
import '../../data/profile_providers.dart';
import '../../data/profile_repository.dart';
import '../updates/update_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final User? user = ref.watch(currentUserProvider).valueOrNull;
    final bool guestMode = ref.watch(guestModeProvider);
    final bool guest = user == null && guestMode;
    final String? avatarUrl = userAvatarUrl(user);
    final String displayName = ref.watch(displayNameProvider);
    final String accountSubtitle =
        user?.email ?? (guest ? 'وضع الزائر · للتصفح فقط' : 'غير مسجل الدخول');
    final bool isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && context.isDark);
    final bool notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final ReminderAccess access =
        ref.watch(reminderAccessProvider).valueOrNull ?? ReminderAccess.denied;
    final bool exactAlarms = ref.watch(exactAlarmProvider).valueOrNull ?? false;
    final UpdateInfo? update = ref.watch(updateInfoProvider).valueOrNull;
    final String version =
        ref.watch(appVersionProvider).valueOrNull ?? AppConfig.appVersion;
    final int newLimit = ref.watch(dailyNewLimitProvider);
    final int reviewLimit = ref.watch(dailyReviewLimitProvider);

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
                    if (user != null) ...<Widget>[
                      const SizedBox(width: 8),
                      _EditNameButton(
                        onTap: () => _editDisplayName(context, ref),
                      ),
                    ],
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
              ],
            ),
            const _SectionLabel('التذكير'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.bell,
                  title: 'التذكير اليومي',
                  subtitle: _reminderSubtitle(
                    enabled: notificationsEnabled,
                    access: access,
                  ),
                  trailing: Switch.adaptive(
                    value: notificationsEnabled,
                    onChanged: (bool value) {
                      ref.read(notificationsEnabledProvider.notifier).state =
                          value;
                      unawaited(
                        ref.read(reminderCoordinatorProvider).refresh(),
                      );
                      if (value && access != ReminderAccess.granted) {
                        unawaited(_askForPermission(context, ref));
                      }
                    },
                  ),
                ),
                if (notificationsEnabled && access != ReminderAccess.granted)
                  _Row(
                    icon: CupertinoIcons.exclamationmark_circle,
                    title: 'الإشعارات موقوفة من النظام',
                    subtitle: 'افتح إعدادات النظام وفعّل الإشعارات لهذا التطبيق ليصلك التذكير.',
                    onTap: () async {
                      await ReminderService.instance.openSystemSettings();
                      ref.invalidate(reminderAccessProvider);
                    },
                  ),
                if (notificationsEnabled &&
                    access == ReminderAccess.granted &&
                    !exactAlarms)
                  _Row(
                    icon: CupertinoIcons.clock,
                    title: 'تذكير في الوقت المحدد',
                    subtitle: 'قد يتأخر التنبيه حتى ساعة بسبب توفير الطاقة. اسمح بالمنبهات الدقيقة.',
                    onTap: () async {
                      await ReminderService.instance.requestExactAlarms();
                      ref.invalidate(exactAlarmProvider);
                      unawaited(
                        ref.read(reminderCoordinatorProvider).refresh(),
                      );
                    },
                  ),
              ],
            ),
            _SectionLabel(
              'أهداف المراجعة',
              onHelp: () => _showGoalsHelp(context),
            ),
            _Group(
              children: <Widget>[
                _StepperRow(
                  icon: CupertinoIcons.sparkles,
                  title: 'بطاقات جديدة',
                  subtitle: 'كم بطاقة جديدة تتعلّمها يومياً',
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
                  title: 'بطاقات المراجعة',
                  subtitle: 'أقصى عدد من البطاقات القديمة يومياً',
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
            const _SectionLabel('عن التطبيق'),
            _Group(
              children: <Widget>[
                _Row(
                  icon: CupertinoIcons.person_crop_circle,
                  title: 'المطور',
                  subtitle: 'حسن المحمد · تواصل مباشر',
                  onTap: () => context.push('/developer'),
                ),
                _Row(
                  icon: CupertinoIcons.lock,
                  title: 'سياسة الخصوصية',
                  subtitle: 'كيف نحمي بياناتك وما نجمعه',
                  onTap: () => context.push('/privacy'),
                ),
                _Row(
                  icon: CupertinoIcons.doc_text,
                  title: 'شروط الاستخدام',
                  subtitle: 'قواعد استخدام التطبيق والمحتوى',
                  onTap: () => context.push('/terms'),
                ),
                if (update != null && update.hasUpdate)
                  _Row(
                    icon: Icons.rocket_launch_rounded,
                    title: 'تحديث متوفر',
                    subtitle:
                        'الإصدار ${update.latestVersion} جاهز للتنزيل — اضغط للتحديث.',
                    onTap: () => showUpdateDialog(context, update),
                  ),
                _Row(
                  icon: CupertinoIcons.info_circle,
                  title: 'الإصدار',
                  subtitle: version,
                  onTap: () => _checkForUpdate(context, ref),
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
              child: Text('صُنع بحب للطلاب', style: context.texts.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  /// Explains the two daily goals in plain language. The row titles alone
  /// ("new cards" / "review cards") do not say whether the number is per
  /// session or per day, which is exactly what confused people.
  Future<void> _showGoalsHelp(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('أهداف المراجعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HelpPoint(
              icon: CupertinoIcons.sparkles,
              title: 'بطاقات جديدة',
              body: 'كم بطاقة جديدة تريد تعلّمها يومياً.',
            ),
            const SizedBox(height: 14),
            _HelpPoint(
              icon: CupertinoIcons.repeat,
              title: 'بطاقات المراجعة',
              body: 'الحد الأقصى للبطاقات القديمة التي ستتم مراجعتها يومياً.',
            ),
            const SizedBox(height: 14),
            Text(
              'البطاقات الزائدة عن الحد تبقى في الانتظار وتظهر في اليوم التالي، '
              'لذلك لا تفوتك أي بطاقة.',
              style: context.texts.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  /// One line that tells the truth about whether a reminder will arrive.
  ///
  /// A switch that reads "on" while the system silently drops every
  /// notification is the worst possible state: the user believes they are
  /// covered and misses a week of reviews.
  static String _reminderSubtitle({
    required bool enabled,
    required ReminderAccess access,
  }) {
    if (!enabled) {
      return 'لن تصلك تنبيهات. يمكنك تفعيلها في أي وقت.';
    }
    switch (access) {
      case ReminderAccess.granted:
        return 'حتى ٦ تنبيهات بين ٨ صباحاً و١٠ مساءً، بحسب عدد البطاقات المستحقة.';
      case ReminderAccess.denied:
      case ReminderAccess.blocked:
        return 'الإشعارات موقوفة من النظام — اسمح بها ليصلك التذكير.';
      case ReminderAccess.unsupported:
        return 'هذا الجهاز لا يدعم الإشعارات.';
    }
  }

  /// Re-asks GitHub when the version row is tapped.
  ///
  /// A failed check is reported as a failure, never as "you are up to date":
  /// claiming that on a timeout is the one answer that could leave someone on
  /// an old build for months.
  Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
    // Invalidate first, then read: the provider is what actually runs the
    // check, so this is one request that also refreshes the row above. Asking
    // the service directly and invalidating afterwards would fire two.
    ref.invalidate(updateInfoProvider);
    final UpdateInfo? info = await ref.read(updateInfoProvider.future);
    if (!context.mounted) {
      return;
    }
    if (info == null) {
      showAppMessage(
        context,
        'تعذّر التحقق من التحديثات. تحقّق من اتصالك وحاول مرة أخرى.',
        kind: AppMessageKind.info,
      );
      return;
    }
    if (!info.hasUpdate) {
      showAppMessage(context, 'أنت على أحدث إصدار (v${info.currentVersion}).');
      return;
    }
    await showUpdateDialog(context, info);
  }

  Future<void> _askForPermission(BuildContext context, WidgetRef ref) async {
    final ReminderAccess result = await ReminderService.instance.request();
    ref.invalidate(reminderAccessProvider);
    if (!context.mounted) {
      return;
    }
    if (result == ReminderAccess.granted) {
      unawaited(ref.read(reminderCoordinatorProvider).refresh());
      return;
    }
    showAppMessage(
      context,
      'لم يُسمح بالإشعارات. يمكنك تفعيلها من إعدادات النظام في أي وقت.',
      kind: AppMessageKind.info,
    );
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

  /// Opens the rename dialog and saves whatever the user confirms.
  ///
  /// The name is written locally first, so it survives a sign-out and shows
  /// up immediately even if the push to Supabase has to wait for a network.
  Future<void> _editDisplayName(BuildContext context, WidgetRef ref) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) =>
          _NameDialog(initial: ref.read(displayNameProvider)),
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(displayNameProvider.notifier).rename(name);
      if (!context.mounted) {
        return;
      }
      showAppMessage(context, 'تم تحديث الاسم.', kind: AppMessageKind.success);
    } on ProfileFailure catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppMessage(context, error.message, kind: AppMessageKind.error);
    }
  }
}

class _EditNameButton extends StatelessWidget {
  const _EditNameButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'تعديل الاسم',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(CupertinoIcons.pencil, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              const Text(
                'تعديل',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small dialog for renaming. Kept local to this file because nothing else
/// needs a single-field prompt.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < ProfileRepository.minNameLength ||
        value.length > ProfileRepository.maxNameLength) {
      setState(() {
        _error = 'الاسم يجب أن يكون بين حرفين و40 حرفاً.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الاسم'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'يظهر هذا الاسم لك في التطبيق، وكمؤلف لمجموعاتك في المكتبة.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            maxLength: ProfileRepository.maxNameLength,
            onSubmitted: (String _) => _submit(),
            decoration: InputDecoration(
              hintText: 'اكتب اسمك',
              errorText: _error,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
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
    return CachedNetworkImage(
      imageUrl: url!,
      width: 54,
      height: 54,
      fit: BoxFit.cover,
      memCacheWidth: 162,
      maxWidthDiskCache: 162,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (BuildContext context, String url, Object error) => label,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.onHelp});

  final String label;

  /// Shows a small (?) next to the label when the section needs explaining.
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.texts.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: context.texts.bodySmall?.color,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 22, onHelp == null ? 24 : 14, 8),
      child: Row(
        children: <Widget>[
          Text(label, style: style),
          if (onHelp != null) ...<Widget>[
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'شرح أهداف المراجعة',
              child: InkWell(
                onTap: onHelp,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.question_circle,
                    size: 15,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
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
              color: context.isDark ? AppColors.darkSurfaceHigh : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: context.colors.primary),
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
            color: enabled ? context.softAccent : context.raisedSurface,
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

class _HelpPoint extends StatelessWidget {
  const _HelpPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.softAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: context.onSoftAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: context.texts.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: context.texts.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
