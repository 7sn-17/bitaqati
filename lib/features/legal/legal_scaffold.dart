import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One numbered clause of a legal page.
@immutable
class LegalSection {
  const LegalSection({
    required this.heading,
    this.paragraphs = const <String>[],
    this.bullets = const <String>[],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

/// Shared frame for the privacy policy and the terms of service.
///
/// Both pages are long-form Arabic text, so they share one layout: a compact
/// header that states when the text last changed, then a column of numbered
/// sections. Keeping the frame in one place means the two documents can never
/// drift apart visually.
class LegalScaffold extends StatelessWidget {
  const LegalScaffold({
    required this.title,
    required this.updatedOn,
    required this.intro,
    required this.sections,
    super.key,
  });

  final String title;
  final String updatedOn;
  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color muted = dark ? context.muted : context.muted;
    final Color heading = dark ? context.ink : context.ink;

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
                  child: Text(title, style: context.texts.headlineMedium),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? context.raisedSurface : context.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: context.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.doc_text,
                          size: 17,
                          color: context.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'آخر تحديث · $updatedOn',
                          style: TextStyle(
                            fontFamily: 'ReadexPro',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    intro,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 13.5,
                      height: 1.9,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            for (int index = 0; index < sections.length; index++)
              _SectionBlock(
                index: index + 1,
                section: sections[index],
                headingColor: heading,
                mutedColor: muted,
              ),
            const SizedBox(height: 8),
            Text(
              'باستخدامك التطبيق فإنك تقرّ بأنك قرأت هذا النص وفهمته.',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.index,
    required this.section,
    required this.headingColor,
    required this.mutedColor,
  });

  final int index;
  final LegalSection section;
  final Color headingColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? context.raisedSurface
                      : context.accentSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.isDark ? context.brandInk : context.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.heading,
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                    color: headingColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final String paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 36),
              child: Text(
                paragraph,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13.5,
                  height: 1.95,
                  color: mutedColor,
                ),
              ),
            ),
          for (final String bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? context.brandInk
                            : context.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13.5,
                        height: 1.9,
                        color: mutedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
            color: context.raisedSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: context.ink,
          ),
        ),
      ),
    );
  }
}
