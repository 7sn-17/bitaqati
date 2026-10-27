import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync_providers.dart';
import '../theme/app_colors.dart';

/// A slim pill that appears while the device has no connection.
///
/// It floats above the tab bar instead of pushing the layout around, so no
/// screen has to know it exists and nothing jumps when the network comes back.
/// The wording is deliberately reassuring: studying works offline, and the
/// queue drains itself as soon as the radio returns.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool online = ref.watch(networkStatusProvider).valueOrNull ?? true;
    return IgnorePointer(
      ignoring: online,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: online ? const Offset(0, 1.6) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: online ? 0 : 1,
          child: const _Pill(),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'لا يوجد اتصال بالإنترنت. المراجعة تعمل، وستُزامن التغييرات تلقائياً.',
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.darkSurfaceHigh
                : AppColors.ink.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                CupertinoIcons.wifi_slash,
                size: 15,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'بدون اتصال · المراجعة تعمل وسيُزامن لاحقاً',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: context.isDark ? AppColors.darkInk : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
