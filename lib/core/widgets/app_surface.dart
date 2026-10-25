import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../i18n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

const EdgeInsets kPagePadding = EdgeInsets.fromLTRB(20, 0, 20, 120);
const double kPageMaxWidth = 760;

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.radius = 22,
    this.onTap,
    this.onLongPress,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Radius r = Radius.circular(radius);
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surfaceContainerLow,
        borderRadius: BorderRadius.all(r),
        border: Border.all(
          color: borderColor ?? colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: child,
    );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.all(r),
        clipBehavior: Clip.antiAlias,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.all(r),
                child: content,
              ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(0, 26, 0, 12),
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: context.colors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: context.texts.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    super.key,
    this.color = AppColors.lime,
    this.size = 48,
    this.iconSize,
    this.radius = 16,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.16)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.48,
        color: isDark ? Color.lerp(color, Colors.white, 0.25) : color,
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    super.key,
    this.selected = false,
    this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color accent = color ?? colors.primary;
    return Material(
      color: selected
          ? accent.withValues(alpha: context.isDark ? 0.22 : 0.14)
          : colors.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? accent : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.texts.labelMedium?.copyWith(
                  color: selected ? accent : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                value,
                style: context.texts.labelLarge?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: context.texts.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    super.key,
    this.size = 58,
    this.strokeWidth = 6,
    this.color,
    this.label,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? context.colors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1),
          color: accent,
          track: context.colors.surfaceContainerHighest,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            label ?? '${(value.clamp(0, 1) * 100).round()}%',
            style: context.texts.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Paint trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final Paint progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 28,
        vertical: compact ? 26 : 44,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 58 : 76,
            height: compact ? 58 : 76,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 27 : 34,
              color: context.colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.texts.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: context.texts.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({required this.label, super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.texts.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppTagWrap extends StatelessWidget {
  const AppTagWrap({
    required this.tags,
    super.key,
    this.maxTags = 4,
    this.onTap,
  });

  final List<String> tags;
  final int maxTags;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .take(maxTags)
          .map(
            (String tag) => GestureDetector(
              onTap: onTap == null ? null : () => onTap!(tag),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.texts.headlineMedium),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: context.texts.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: error ? AppColors.coral : AppColors.lime,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

String privacyLabel(BuildContext context, DeckPrivacy privacy) {
  final AppStrings strings = context.strings;
  return switch (privacy) {
    DeckPrivacy.public => strings.publicLabel,
    DeckPrivacy.unlisted => strings.unlistedLabel,
    DeckPrivacy.private => strings.privateLabel,
  };
}
