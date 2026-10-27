import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.color,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? context.colors.surfaceContainerHighest;
    final BorderSide side = context.isDark
        ? BorderSide(color: context.colors.outlineVariant, width: 0.8)
        : BorderSide.none;
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: resolved,
          borderRadius: BorderRadius.circular(radius),
          border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        ),
        child: child,
      );
    }
    return Material(
      color: resolved,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
