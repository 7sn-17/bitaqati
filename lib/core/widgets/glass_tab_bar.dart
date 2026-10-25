import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onCreate,
    this.dueCount = 0,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final int dueCount;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(
      label: 'الرئيسية',
      icon: CupertinoIcons.house,
      activeIcon: CupertinoIcons.house_fill,
    ),
    _TabSpec(
      label: 'مجموعاتي',
      icon: CupertinoIcons.rectangle_stack,
      activeIcon: CupertinoIcons.rectangle_stack_fill,
    ),
    _TabSpec(
      label: 'المكتبة',
      icon: CupertinoIcons.book,
      activeIcon: CupertinoIcons.book_fill,
    ),
    _TabSpec(
      label: 'تقدّمي',
      icon: CupertinoIcons.chart_bar,
      activeIcon: CupertinoIcons.chart_bar_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color inactive = isDark ? AppColors.darkMuted : AppColors.muted;
    final Color active = context.colors.primary;
    final Color barColor = isDark
        ? AppColors.darkCanvas.withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.84);
    final Color border = isDark ? AppColors.darkLine : AppColors.line;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: barColor,
            border: Border(top: BorderSide(color: border, width: 0.6)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 3),
            child: SizedBox(
              height: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: _TabItem(
                      spec: _tabs[0],
                      selected: currentIndex == 0,
                      activeColor: active,
                      inactiveColor: inactive,
                      badge: dueCount,
                      onTap: () => onSelect(0),
                    ),
                  ),
                  Expanded(
                    child: _TabItem(
                      spec: _tabs[1],
                      selected: currentIndex == 1,
                      activeColor: active,
                      inactiveColor: inactive,
                      onTap: () => onSelect(1),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -12),
                        child: _CreateButton(onTap: onCreate, isDark: isDark),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TabItem(
                      spec: _tabs[2],
                      selected: currentIndex == 2,
                      activeColor: active,
                      inactiveColor: inactive,
                      onTap: () => onSelect(2),
                    ),
                  ),
                  Expanded(
                    child: _TabItem(
                      spec: _tabs[3],
                      selected: currentIndex == 3,
                      activeColor: active,
                      inactiveColor: inactive,
                      onTap: () => onSelect(3),
                    ),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.badge = 0,
  });

  final _TabSpec spec;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  selected ? spec.activeIcon : spec.icon,
                  size: 24,
                  color: color,
                ),
                if (badge > 0)
                  PositionedDirectional(
                    top: -3,
                    start: -7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 15),
                      height: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 9.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap, required this.isDark});

  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color background = isDark ? AppColors.accent : AppColors.primary;
    final Color foreground = isDark ? AppColors.primary : AppColors.accent;
    return Semantics(
      button: true,
      label: 'إنشاء',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: background.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(CupertinoIcons.plus, size: 26, color: foreground),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
