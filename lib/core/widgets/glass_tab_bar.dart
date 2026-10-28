import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Floating, blurred tab bar with a raised centre "+" button.
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

  static const double _barHeight = 64;
  static const double _createSize = 58;

  /// How much room the floating bar takes from the bottom of the screen,
  /// including its own padding. Anything that floats above it — the offline
  /// banner — offsets itself by this.
  static const double reservedHeight = _barHeight + 24;

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

  Widget _item(int tab, Color active, Color inactive) {
    return Expanded(
      child: _TabItem(
        spec: _tabs[tab],
        selected: currentIndex == tab,
        activeColor: active,
        inactiveColor: inactive,
        badge: tab == 0 ? dueCount : 0,
        onTap: () => onSelect(tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color inactive = isDark ? context.muted : context.muted;
    final Color active = isDark ? context.accent : context.primary;
    final Color barColor = isDark
        ? context.cardSurface.withValues(alpha: 0.76)
        : Colors.white.withValues(alpha: 0.74);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.07);
    final BorderRadius radius = BorderRadius.circular(32);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          height: _barHeight + 12,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: radius,
                        border: Border.all(color: border, width: 0.8),
                      ),
                      child: Row(
                        children: <Widget>[
                          _item(0, active, inactive),
                          _item(1, active, inactive),
                          const SizedBox(width: _createSize + 6),
                          _item(2, active, inactive),
                          _item(3, active, inactive),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(top: 0, child: _CreateButton(onTap: onCreate)),
            ],
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
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: selected ? 46 : 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Icon(
                  selected ? spec.activeIcon : spec.icon,
                  size: 22,
                  color: color,
                ),
                if (badge > 0)
                  PositionedDirectional(
                    top: -5,
                    start: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 15),
                      height: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: context.danger,
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
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color background = isDark ? context.accent : context.primary;
    final Color foreground = isDark ? context.primary : context.accent;
    return Semantics(
      button: true,
      label: 'إنشاء',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: GlassTabBar._createSize,
          height: GlassTabBar._createSize,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.surface, width: 4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: background.withValues(alpha: 0.36),
                blurRadius: 18,
                offset: const Offset(0, 8),
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
