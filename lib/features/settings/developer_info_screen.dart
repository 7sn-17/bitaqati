import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';

/// Who built the app, and how to reach them.
///
/// The contact rows are the only interactive part: each one hands a URI to
/// the operating system so the mail client, WhatsApp or Instagram opens in
/// its own app rather than an in-app browser.
class DeveloperInfoScreen extends StatelessWidget {
  const DeveloperInfoScreen({super.key});

  static const String _name = 'حسن المحمد';
  static const String _role = 'طالب · مطوّر التطبيق';
  static const String _email = 'hasantaha5689@gmail.com';
  static const String _instagram = 'https://instagram.com/7sn__08';
  static const String _whatsapp = 'https://wa.me/963984623461';
  static const String _telegram = 'https://t.me/DOVx3';

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color muted = dark ? AppColors.darkMuted : AppColors.muted;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: <Widget>[
            Row(
              children: <Widget>[
                _BackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المطور',
                    style: context.texts.headlineMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Hero(name: _name, role: _role),
            const SizedBox(height: 22),
            Text(
              'تواصل معي',
              style: TextStyle(
                fontFamily: 'ReadexPro',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: dark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'أسئلة، اقتراحات، أو بلاغ عن محتوى — كل رسالة تصلني مباشرة.',
              style: context.texts.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 14),
            _ContactCard(
              icon: CupertinoIcons.mail_solid,
              label: 'البريد الإلكتروني',
              value: _email,
              tint: AppColors.blue,
              onTap: () => _open(context, 'mailto:$_email'),
            ),
            _ContactCard(
              icon: CupertinoIcons.chat_bubble_2_fill,
              label: 'واتساب',
              value: '+963 984 623 461',
              tint: const Color(0xFF1F9D55),
              onTap: () => _open(context, _whatsapp),
            ),
            _ContactCard(
              icon: CupertinoIcons.paperplane_fill,
              label: 'تيليجرام',
              value: '@DOVx3',
              tint: const Color(0xFF229ED9),
              onTap: () => _open(context, _telegram),
            ),
            _ContactCard(
              icon: CupertinoIcons.camera_fill,
              label: 'إنستغرام',
              value: '@7sn__08',
              tint: const Color(0xFFC13584),
              onTap: () => _open(context, _instagram),
            ),
            const SizedBox(height: 26),
            Center(
              child: Text(
                'صُنع بحب للطلاب',
                style: context.texts.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands [url] to the platform. Falls back to an in-app browser when no
  /// dedicated app is installed, and says so when nothing can open it.
  Future<void> _open(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) {
      return;
    }
    showAppMessage(
      context,
      'تعذّر فتح هذا العنوان على هذا الجهاز.',
      kind: AppMessageKind.error,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primary, AppColors.primaryDeep],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 3,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'ح',
              style: TextStyle(
                fontFamily: 'ReadexPro',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: dark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: dark ? 0.24 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'ReadexPro',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: dark ? AppColors.darkInk : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 12.5,
                          color: dark ? AppColors.darkMuted : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.arrow_up_right,
                  size: 16,
                  color: dark ? AppColors.darkMuted : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'رجوع',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkSurfaceHigh : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: context.isDark ? AppColors.darkInk : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
