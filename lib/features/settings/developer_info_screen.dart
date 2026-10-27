import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  static const String _photo = 'https://iili.io/nvhi46B.jpg';

  // Brand colours, taken from each network's own guidelines.
  static const Color _whatsappGreen = Color(0xFF25D366);
  static const Color _telegramBlue = Color(0xFF229ED9);
  static const List<Color> _instagramGradient = <Color>[
    Color(0xFF833AB4),
    Color(0xFFFD1D1D),
    Color(0xFFF56040),
    Color(0xFFFFDC80),
  ];

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
            _Hero(name: _name, role: _role, photo: _photo),
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
              icon: FontAwesomeIcons.envelope,
              label: 'البريد الإلكتروني',
              value: _email,
              tint: AppColors.blue,
              onTap: () => _open(context, 'mailto:$_email'),
            ),
            _ContactCard(
              icon: FontAwesomeIcons.whatsapp,
              label: 'واتساب',
              value: '+963 984 623 461',
              tint: _whatsappGreen,
              onTap: () => _open(context, _whatsapp),
            ),
            _ContactCard(
              icon: FontAwesomeIcons.telegram,
              label: 'تيليجرام',
              value: '@DOVx3',
              tint: _telegramBlue,
              onTap: () => _open(context, _telegram),
            ),
            _ContactCard(
              icon: FontAwesomeIcons.instagram,
              label: 'إنستغرام',
              value: '@7sn__08',
              tint: const Color(0xFFE1306C),
              gradient: _instagramGradient,
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
  const _Hero({
    required this.name,
    required this.role,
    required this.photo,
  });

  final String name;
  final String role;
  final String photo;

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
          _Avatar(photo: photo, initial: name.substring(0, 1)),
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
    this.gradient,
  });

  final FaIconData icon;
  final String label;
  final String value;

  /// Brand colour. Fills the icon and, at low opacity, the tile behind it.
  final Color tint;

  /// Some brands (Instagram) are only recognisable as a gradient.
  final List<Color>? gradient;

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
                _BrandBadge(
                  icon: icon,
                  tint: tint,
                  gradient: gradient,
                  dark: dark,
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

/// The developer's photo, cached on disk so the header still shows a face
/// with no connection. Falls back to the initial when the image cannot load.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo, required this.initial});

  final String photo;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[AppColors.accent, Color(0xFF63C13A)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: photo,
          fit: BoxFit.cover,
          memCacheWidth: 276,
          maxWidthDiskCache: 276,
          fadeInDuration: const Duration(milliseconds: 260),
          placeholder: (BuildContext context, String url) => _fallback(),
          errorWidget:
              (BuildContext context, String url, Object error) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.accent,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'ReadexPro',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// The square that holds a brand logo: a wash of the brand colour behind the
/// logo itself, so the row reads as "WhatsApp" at a glance instead of
/// "generic chat bubble".
class _BrandBadge extends StatelessWidget {
  const _BrandBadge({
    required this.icon,
    required this.tint,
    required this.dark,
    this.gradient,
  });

  final FaIconData icon;
  final Color tint;
  final bool dark;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final List<Color>? colors = gradient;
    final Widget glyph = FaIcon(icon, size: 19, color: tint);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors == null
            ? tint.withValues(alpha: dark ? 0.22 : 0.11)
            : null,
        gradient: colors == null
            ? null
            : LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  for (final Color color in colors)
                    color.withValues(alpha: dark ? 0.26 : 0.14),
                ],
              ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: colors == null
          ? glyph
          : ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (Rect bounds) => LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: colors,
              ).createShader(bounds),
              child: FaIcon(icon, size: 19, color: Colors.white),
            ),
    );
  }
}
