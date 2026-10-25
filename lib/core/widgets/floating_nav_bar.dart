import 'dart:ui';

import 'package:flutter/material.dart';

import '../i18n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onCreate,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final ColorScheme colors = context.colors;
    final bool isDark = context.isDark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: isDark ? 0.8 : 0.7),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.1),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: colors.surfaceContainerLow.withValues(
                alpha: isDark ? 0.86 : 0.9,
              ),
              child: Row(
                children: <Widget>[
                  _NavItem(
                    icon: Icons.home_rounded,
                    outlinedIcon: Icons.home_outlined,
                    label: strings.home,
                    selected: currentIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _NavItem(
                    icon: Icons.auto_stories_rounded,
                    outlinedIcon: Icons.auto_stories_outlined,
                    label: strings.library,
                    selected: currentIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  Expanded(
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: strings.create,
                        child: GestureDetector(
                          onTap: onCreate,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.lime : AppColors.forest,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color:
                                      (isDark
                                              ? AppColors.lime
                                              : AppColors.forest)
                                          .withValues(alpha: 0.32),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: isDark ? AppColors.forest : Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.insights_rounded,
                    outlinedIcon: Icons.insights_outlined,
                    label: strings.progress,
                    selected: currentIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                  _NavItem(
                    icon: Icons.tune_rounded,
                    outlinedIcon: Icons.tune_outlined,
                    label: strings.settings,
                    selected: currentIndex == 3,
                    onTap: () => onSelect(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color active = context.isDark ? AppColors.lime : AppColors.forest;
    final Color inactive = context.colors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                selected ? icon : outlinedIcon,
                size: 22,
                color: selected ? active : inactive,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: context.texts.labelSmall?.copyWith(
                  color: selected ? active : inactive,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
