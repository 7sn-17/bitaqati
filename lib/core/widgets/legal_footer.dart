import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Opens a legal page on top of the current screen.
///
/// These pages are pushed on the navigator rather than through go_router,
/// because the router redirects anyone who is not signed in back to the login
/// screen — and the login and onboarding screens are exactly where the links
/// live.
void openLegalPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (BuildContext _) => page),
  );
}

/// The "by continuing you agree to..." line with two tappable links.
///
/// Shared by the login and onboarding screens so the wording, the colour
/// and the underline can never drift apart. The recognizers are owned by
/// the state because they hold callbacks that reference this widget.
class LegalFooterLinks extends StatefulWidget {
  const LegalFooterLinks({
    required this.onPrivacy,
    required this.onTerms,
    super.key,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  @override
  State<LegalFooterLinks> createState() => _LegalFooterLinksState();
}

class _LegalFooterLinksState extends State<LegalFooterLinks> {
  late final TapGestureRecognizer _privacy;
  late final TapGestureRecognizer _terms;

  @override
  void initState() {
    super.initState();
    _privacy = TapGestureRecognizer()..onTap = widget.onPrivacy;
    _terms = TapGestureRecognizer()..onTap = widget.onTerms;
  }

  @override
  void dispose() {
    _privacy.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = context.texts.bodySmall?.color ?? AppColors.muted;
    final Color link = context.isDark
        ? const Color(0xFF8EC5E8)
        : AppColors.blue;
    final TextStyle baseStyle = TextStyle(
      fontFamily: 'IBMPlexSansArabic',
      fontSize: 10.5,
      height: 1.8,
      color: base,
    );
    final TextStyle linkStyle = baseStyle.copyWith(
      color: link,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: link,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          const TextSpan(text: 'بالمتابعة أنت توافق على '),
          TextSpan(
            text: 'سياسة الخصوصية',
            style: linkStyle,
            recognizer: _privacy,
          ),
          const TextSpan(text: ' و'),
          TextSpan(
            text: 'شروط الاستخدام',
            style: linkStyle,
            recognizer: _terms,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
