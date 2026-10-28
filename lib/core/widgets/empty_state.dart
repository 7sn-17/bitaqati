import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_palette.dart';

/// The one empty state used across the app.
///
/// Every list that can be empty renders this instead of a bare "nothing here",
/// so an empty screen still feels finished: an illustration-ish badge, a
/// sentence that explains why it is empty, and one obvious next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final Color accent = tint ?? context.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: context.isDark ? 0.16 : 0.22),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 40,
              color: context.isDark ? accent : context.primaryDeep,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: context.muted),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 18),
            Semantics(
              button: true,
              label: actionLabel,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  // [tint] can be any brand colour, so the label is made
                  // readable against whatever it actually is.
                  foregroundColor: ThemePalette.readable(Colors.white, accent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'ReadexPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
