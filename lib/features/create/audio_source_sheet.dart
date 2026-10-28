import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Where a new voice note comes from.
enum AudioSourceChoice { record, file }

/// Asks whether the learner wants to record a new voice note or attach one
/// they already have.
///
/// The audio button used to open the file picker straight away, which meant a
/// phone with no recordings on it had no way to add sound at all. The sheet
/// makes recording the first, obvious option and keeps the picker one tap away.
Future<AudioSourceChoice?> showAudioSourceSheet(BuildContext context) {
  return showModalBottomSheet<AudioSourceChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    useSafeArea: true,
    builder: (BuildContext context) => const _AudioSourceSheet(),
  );
}

class _AudioSourceSheet extends StatelessWidget {
  const _AudioSourceSheet();

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.6 : 0.24),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: context.muted.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'إرفاق صوت',
                style: context.texts.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'سجّل صوتك الآن، أو أرفق مقطعاً موجوداً على جهازك.',
                style: context.texts.bodySmall?.copyWith(color: context.muted),
              ),
              const SizedBox(height: 16),
              _Choice(
                icon: CupertinoIcons.mic_fill,
                title: 'تسجيل صوتي جديد',
                subtitle: 'اقرأ الإجابة بصوتك، وستُرفق بالبطاقة.',
                tint: context.danger,
                onTap: () =>
                    Navigator.of(context).pop(AudioSourceChoice.record),
              ),
              const SizedBox(height: 10),
              _Choice(
                icon: CupertinoIcons.folder,
                title: 'اختيار من الملفات',
                subtitle: 'ملف mp3 أو m4a أو wav من ذاكرة الجهاز.',
                tint: context.info,
                onTap: () => Navigator.of(context).pop(AudioSourceChoice.file),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.raisedSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_back, size: 15, color: context.muted),
            ],
          ),
        ),
      ),
    );
  }
}
