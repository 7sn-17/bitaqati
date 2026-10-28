import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/legal_footer.dart';
import '../../core/dynamic_icon.dart';
import '../../data/auth_service.dart';
import '../../data/icon_providers.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_of_service_screen.dart';

/// Entry screen shown after onboarding: native Google sign-in or guest mode.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final GuestModeNotifier guestMode = ref.read(guestModeProvider.notifier);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      await guestMode.exit();
      // The router redirects to /home once the session is visible.
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      final bool canceled =
          error.code == 'canceled' ||
          error.code == 'sign_in_canceled' ||
          error.code == '16' ||
          error.code == '12501';
      if (canceled) {
        // A real cancellation is not an error state: no red box, just a short
        // polite note.
        showAppMessage(context, error.message, kind: AppMessageKind.info);
      } else {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر إكمال تسجيل الدخول. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    await ref.read(guestModeProvider.notifier).enter();
  }

  @override
  Widget build(BuildContext context) {
    final bool canUseGoogle =
        AppConfig.hasGoogleSignIn && AppConfig.hasSupabase;
    // The icon this install is wearing, and the field it sits on. The first
    // screen should look like the icon on the home screen: a phone wearing the
    // blue icon used to open onto the yellow one.
    final AppIconOption icon = ref.watch(activeIconProvider);

    return Scaffold(
      backgroundColor: icon.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The form is centred vertically, and still scrolls when the
            // keyboard shrinks the viewport.
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _LoginMark(icon: icon),
                      const SizedBox(height: 26),
                      // The form keeps the normal surface and its normal ink.
                      // Painting it straight onto the icon field would mean
                      // re-colouring every label, error box and divider by
                      // hand, and one of them would be missed.
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        decoration: BoxDecoration(
                          color: context.cardSurface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _form(context, canUseGoogle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context, bool canUseGoogle) {
    return <Widget>[
      Text(
        'مرحباً بك في بطاقاتي',
        textAlign: TextAlign.center,
        style: context.texts.displaySmall,
      ),
      const SizedBox(height: 8),
      Text(
        'سجّل الدخول لتنشئ مجموعاتك وبطاقاتك وتحفظ تقدّمك '
        'في كل أجهزتك.',
        textAlign: TextAlign.center,
        style: context.texts.bodySmall?.copyWith(height: 1.8),
      ),
      const SizedBox(height: 26),
      if (_error != null) ...<Widget>[
        _ErrorBox(message: _error!),
        const SizedBox(height: 14),
      ],
      SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: _busy || !canUseGoogle ? null : _signInWithGoogle,
          style: OutlinedButton.styleFrom(
            backgroundColor: context.raisedSurface,
            side: BorderSide(color: context.colors.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const _GoogleMark(),
                    const SizedBox(width: 10),
                    Text(
                      'المتابعة بحساب Google',
                      style: context.texts.titleSmall,
                    ),
                  ],
                ),
        ),
      ),
      if (!canUseGoogle) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          'تسجيل الدخول بجوجل غير مهيّأ في هذا البناء. '
          'أضف GOOGLE_WEB_CLIENT_ID وبيانات Supabase.',
          textAlign: TextAlign.center,
          style: context.texts.bodySmall?.copyWith(
            color: context.danger,
            height: 1.7,
          ),
        ),
      ],
      const SizedBox(height: 18),
      Row(
        children: <Widget>[
          Expanded(child: Divider(color: context.colors.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('أو', style: context.texts.labelSmall),
          ),
          Expanded(child: Divider(color: context.colors.outlineVariant)),
        ],
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _continueAsGuest,
          icon: const Icon(CupertinoIcons.person, size: 18),
          label: const Text('المتابعة كزائر'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.onSurface,
            side: BorderSide(color: context.colors.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: context.texts.titleSmall,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'وضع الزائر للتصفح فقط: إنشاء المجموعات والبطاقات '
        'يتطلب حساباً.',
        textAlign: TextAlign.center,
        style: context.texts.bodySmall?.copyWith(fontSize: 11, height: 1.7),
      ),
      const SizedBox(height: 22),
      LegalFooterLinks(
        onPrivacy: () => openLegalPage(context, const PrivacyPolicyScreen()),
        onTerms: () => openLegalPage(context, const TermsOfServiceScreen()),
      ),
    ];
  }
}

/// The launcher icon, on its own field, above the form.
///
/// The artwork is the full-bleed file rather than the composed adaptive one:
/// a rounded square is the shape this screen wants, and the adaptive file is
/// already inset for the launcher's circular mask.
class _LoginMark extends StatelessWidget {
  const _LoginMark({required this.icon});

  final AppIconOption icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            icon.asset,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// Official multi-colour Google "G" mark from `assets/branding/google_g.svg`.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/google_g.svg',
      width: 20,
      height: 20,
      semanticsLabel: 'Google',
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 18,
            color: context.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodySmall?.copyWith(
                color: context.danger,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
