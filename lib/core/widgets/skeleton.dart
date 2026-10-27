import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A shimmering placeholder block.
///
/// Used instead of a spinner wherever content has a known shape, so the screen
/// keeps its layout while the first frame of data arrives instead of collapsing
/// to a centred spinner and jumping back.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 14,
    this.radius = 8,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurfaceHigh : Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps a tree of [SkeletonBox]es in one shared shimmer sweep.
///
/// One wrapper per screen rather than one per box: the gradient then travels
/// across the whole layout, which is what makes it read as "loading" instead
/// of "a lot of little grey bars".
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.isDark ? AppColors.darkSurfaceHigh : Colors.white,
      highlightColor: context.isDark
          ? AppColors.darkSurfaceHigh.withValues(alpha: 0.45)
          : AppColors.accentSoft,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Placeholder shaped like a deck tile, for the library and deck lists.
class DeckTileSkeleton extends StatelessWidget {
  const DeckTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          const SkeletonBox(width: 46, height: 46, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBox(width: 150, height: 13),
                const SizedBox(height: 8),
                const SkeletonBox(width: 90, height: 10, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 38, height: 24, radius: 12),
        ],
      ),
    );
  }
}
