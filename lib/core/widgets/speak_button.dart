import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../tts/tts_service.dart';
import 'card_markup.dart';

/// A round speaker button that reads [text] out loud.
///
/// While the engine is talking the icon breathes and a soft ring pulses, so
/// the button shows what it is doing instead of just changing colour. Tap
/// again to stop early.
class SpeakButton extends StatefulWidget {
  const SpeakButton({
    required this.text,
    this.size = 40,
    this.tint,
    this.tooltip = 'استمع للنطق',
    super.key,
  });

  final String text;
  final double size;
  final Color? tint;
  final String tooltip;

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _speaking = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Markup is for the eye, not the voice: `**bold**`, `{{c1::…}}` and image
  /// tokens are stripped so the engine reads the sentence, not the syntax.
  String get _spoken => plainMarkup(widget.text);

  bool get _hasText => _spoken.trim().isNotEmpty;

  Future<void> _toggle() async {
    if (!_hasText) {
      return;
    }
    if (_speaking) {
      await TtsService.instance.stop();
      if (mounted) {
        setState(() => _speaking = false);
      }
      return;
    }
    setState(() => _speaking = true);
    _pulse.repeat(reverse: true);
    await TtsService.instance.speak(_spoken);
    if (!mounted) {
      return;
    }
    _pulse.stop();
    _pulse.value = 0;
    setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color tint =
        widget.tint ??
        (context.isDark ? AppColors.darkAccent : AppColors.primary);
    final bool enabled = _hasText;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) {
          final double t = _pulse.value;
          return Transform.scale(
            scale: _speaking ? 1 + t * 0.06 : 1,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: enabled
                    ? tint.withValues(alpha: _speaking ? 0.22 : 0.12)
                    : tint.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: tint.withValues(alpha: _speaking ? 0.55 : 0.22),
                ),
                boxShadow: _speaking
                    ? <BoxShadow>[
                        BoxShadow(
                          color: tint.withValues(alpha: 0.18 + t * 0.16),
                          blurRadius: 14 + t * 12,
                          spreadRadius: t * 3,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? _toggle : null,
                  child: Icon(
                    _speaking
                        ? CupertinoIcons.speaker_3_fill
                        : CupertinoIcons.speaker_2_fill,
                    size: widget.size * 0.42,
                    color: enabled ? tint : tint.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
