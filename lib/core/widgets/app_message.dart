import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum AppMessageKind { success, error, info }

OverlayEntry? _activeMessage;

/// Shows a short message pinned to the top of the screen.
///
/// A rounded dark card with a status badge and one line of text, no emoji.
/// It sits in the root overlay, so it stays visible above sheets and
/// dialogs. Tap it or swipe it up to dismiss; otherwise it fades after a
/// few seconds. Showing a new message replaces the current one.
void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageKind kind = AppMessageKind.success,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  _activeMessage?.remove();
  _activeMessage = null;

  bool removed = false;
  late final OverlayEntry entry;
  void dismiss() {
    if (removed) {
      return;
    }
    removed = true;
    entry.remove();
    if (identical(_activeMessage, entry)) {
      _activeMessage = null;
    }
  }

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) =>
        _TopMessage(message: message, kind: kind, onDone: dismiss),
  );
  _activeMessage = entry;
  overlay.insert(entry);
}

class _TopMessage extends StatefulWidget {
  const _TopMessage({
    required this.message,
    required this.kind,
    required this.onDone,
  });

  final String message;
  final AppMessageKind kind;
  final VoidCallback onDone;

  @override
  State<_TopMessage> createState() => _TopMessageState();
}

class _TopMessageState extends State<_TopMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.7),
    end: Offset.zero,
  ).animate(_curve);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 3400), _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    if (mounted) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color surface = isDark
        ? AppColors.darkSurfaceHigh
        : AppColors.primary;
    final Color badge = switch (widget.kind) {
      AppMessageKind.success => AppColors.accent,
      AppMessageKind.error => AppColors.danger,
      AppMessageKind.info => AppColors.accentSoft,
    };
    final Color badgeIcon = widget.kind == AppMessageKind.error
        ? Colors.white
        : AppColors.primary;
    final IconData icon = switch (widget.kind) {
      AppMessageKind.success => CupertinoIcons.checkmark_alt,
      AppMessageKind.error => CupertinoIcons.exclamationmark,
      AppMessageKind.info => CupertinoIcons.info,
    };

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: _slide,
              child: Material(
                type: MaterialType.transparency,
                child: Semantics(
                  liveRegion: true,
                  child: GestureDetector(
                    onTap: _close,
                    onVerticalDragEnd: (DragEndDetails details) {
                      if ((details.primaryVelocity ?? 0) < -100) {
                        _close();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 11, 16, 11),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.14 : 0.08,
                          ),
                          width: 0.8,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: badge,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 18, color: badgeIcon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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
