import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/updates/update_providers.dart';
import '../../core/updates/update_service.dart';
import '../../core/widgets/app_message.dart';

/// Shows the update sheet, or does nothing when there is nothing to install.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'تحديث',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) => UpdateDialog(info: info),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              child: child,
            ),
          );
        },
  );
}

/// The update card: a glowing frame around a rocket, the version jump, the
/// release notes and one unmissable button.
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({required this.info, super.key});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _GlowFrame(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _Rocket(),
                  const SizedBox(height: 16),
                  Text(
                    'تحديث متوفر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ReadexPro',
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: context.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _subtitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: context.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _VersionFlow(
                    current: info.currentVersion,
                    latest: info.latestVersion,
                  ),
                  const SizedBox(height: 18),
                  _Notes(text: info.releaseNotes),
                  const SizedBox(height: 18),
                  _PrimaryButton(
                    onTap: () => _open(context, ref),
                    label: 'تحديث الآن',
                  ),
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(updateDismissedProvider.notifier)
                          .dismiss(info.latestVersion);
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: context.muted,
                      minimumSize: const Size(64, 42),
                      textStyle: const TextStyle(
                        fontFamily: 'ReadexPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('لاحقاً'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final DateTime? published = info.publishedAt;
    final String since = published == null ? '' : ' · ${_ago(published)}';
    return 'الإصدار ${info.latestVersion} جاهز للتنزيل$since';
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final bool opened = await openUpdateDownload(info);
    if (!context.mounted) {
      return;
    }
    if (!opened) {
      showAppMessage(
        context,
        'تعذّر فتح المتصفح. جرّب مرة أخرى أو حمّل من صفحة الإصدارات.',
        kind: AppMessageKind.error,
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

/// Opens the APK download in the system browser.
///
/// The download is handed to the browser on purpose: Android will not let an
/// app install a package it downloaded itself without a second permission,
/// and the browser already knows how to show progress and resume.
Future<bool> openUpdateDownload(UpdateInfo info) async {
  final Uri uri = Uri.parse(info.downloadUrl);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Could not open the download page: $error');
    return false;
  }
}

/// The glowing frame. The shadow breathes so the card feels alive without
/// anything moving that would make the text harder to read.
class _GlowFrame extends StatefulWidget {
  const _GlowFrame({required this.child});

  final Widget child;

  @override
  State<_GlowFrame> createState() => _GlowFrameState();
}

class _GlowFrameState extends State<_GlowFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final Animation<double> _glow = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color surface = context.cardSurface;
    return AnimatedBuilder(
      animation: _glow,
      builder: (BuildContext context, Widget? child) {
        final double t = _glow.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                context.accent,
                context.info,
                context.accentDeep,
                context.accent,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.accent.withValues(alpha: 0.14 + 0.18 * t),
                blurRadius: 30 + 16 * t,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: context.info.withValues(alpha: 0.08 + 0.1 * t),
                blurRadius: 44,
                spreadRadius: -12,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.6),
          child: child,
        );
      },
      // Material, not a bare DecoratedBox: the buttons inside are Material
      // widgets and assert for an ancestor when one is missing.
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(30.4),
        clipBehavior: Clip.antiAlias,
        child: widget.child,
      ),
    );
  }
}

/// Rocket in a brand-gradient disc with a soft halo behind it.
class _Rocket extends StatefulWidget {
  const _Rocket();

  @override
  State<_Rocket> createState() => _RocketState();
}

class _RocketState extends State<_Rocket> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  late final Animation<double> _lift = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 118,
      child: AnimatedBuilder(
        animation: _lift,
        builder: (BuildContext context, Widget? child) {
          final double t = _lift.value;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 100 + 16 * t,
                height: 100 + 16 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      context.accent.withValues(alpha: 0.30 - 0.10 * t),
                      context.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Transform.translate(offset: Offset(0, -3 * t), child: child),
            ],
          );
        },
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[context.accent, context.accentDeep],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.accent.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.rocket_launch_rounded,
            size: 36,
            color: context.primary,
          ),
        ),
      ),
    );
  }
}

/// `v1.0.0 → v1.1.0`, read in the direction the page reads.
///
/// In Arabic the row lays out right to left, so the installed version lands
/// on the right and the new one on the left, and the arrow has to point left
/// to mean "from here to there". Forcing the row to LTR — as this did — put
/// the new version on the far side of an arrow aimed at the old one, so the
/// jump read backwards.
class _VersionFlow extends StatelessWidget {
  const _VersionFlow({required this.current, required this.latest});

  final String current;
  final String latest;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _VersionChip(label: 'v$current', highlighted: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          // The arrow glyphs are mirrored by the framework in RTL, which
          // would flip a left arrow back into a right one. Pinning the
          // icon's own direction leaves the choice above as the only thing
          // that decides which way it points.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Icon(
              rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
              size: 17,
              color: context.muted,
            ),
          ),
        ),
        _VersionChip(label: 'v$latest', highlighted: true),
      ],
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color fill = highlighted
        ? context.selectedFill
        : (context.raisedSurface);
    final Color ink = highlighted ? context.onSoftAccent : context.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: highlighted
            ? Border.all(color: context.accent.withValues(alpha: 0.7))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'ReadexPro',
          fontSize: highlighted ? 13.5 : 12.5,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          color: ink,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// "ما الجديد", scrollable so a long changelog never pushes the buttons off
/// the screen.
class _Notes extends StatelessWidget {
  const _Notes({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final String body = _clean(text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
      decoration: BoxDecoration(
        color: context.isDark
            ? context.raisedSurface.withValues(alpha: 0.55)
            : context.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 15, color: context.accent),
              const SizedBox(width: 7),
              Text(
                'ما الجديد',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: SingleChildScrollView(
              child: Text(
                body.isEmpty ? 'تحسينات في الأداء والاستقرار.' : body,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.75,
                  color: context.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Turns GitHub markdown into something that reads well in a plain Text.
  ///
  /// Release notes are written by hand in CHANGELOG.md and arrive with
  /// heading marks, bullet dashes, bold markers and sometimes a link. None of
  /// that survives into the dialog: what the reader gets is the sentences,
  /// one paragraph per block, with bullets as dots.
  static String _clean(String raw) {
    final List<String> lines = raw.replaceAll('\r\n', '\n').split('\n').map((
      String line,
    ) {
      String value = line.trim();
      if (value.isEmpty) {
        return '';
      }
      value = value
          .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]+\)'),
            (Match match) => match.group(1) ?? '',
          )
          .replaceAll(RegExp(r'^#{1,6}\s*'), '')
          .replaceAll('**', '')
          .replaceAll('__', '')
          .replaceAll('`', '');
      if (value.startsWith('- ') || value.startsWith('* ')) {
        value = value.substring(2);
        value = '•  $value';
      }
      return value;
    }).toList();

    // Exactly one blank line between blocks, whatever the source had. A
    // pasted changelog with three blank lines should not open a gap in a
    // 168px box.
    final StringBuffer buffer = StringBuffer();
    int blanks = 0;
    for (final String line in lines) {
      if (line.isEmpty) {
        blanks++;
        continue;
      }
      if (buffer.isNotEmpty && blanks > 0) {
        buffer.writeln();
      }
      buffer.writeln(line);
      blanks = 0;
    }
    return buffer.toString().trim();
  }
}

/// The one obvious action, on the brand gradient.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[context.accent, context.accentDeep],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'ReadexPro',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _ago(DateTime when) {
  final Duration gap = DateTime.now().difference(when);
  if (gap.inMinutes < 60) {
    return 'قبل قليل';
  }
  if (gap.inHours < 24) {
    return 'قبل ${gap.inHours} ساعة';
  }
  if (gap.inDays < 30) {
    return 'قبل ${gap.inDays} يوم';
  }
  final int months = (gap.inDays / 30).round();
  return months <= 1 ? 'قبل شهر' : 'قبل $months أشهر';
}
