import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/guest_guard.dart';
import '../../core/notifications/reminder_providers.dart';
import '../../core/widgets/glass_tab_bar.dart';
import '../../core/widgets/offline_banner.dart';
import '../../data/content_providers.dart';
import '../../data/sync_providers.dart';
import '../create/create_sheet.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The floating bar would ride above the keyboard, so hide it while typing.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final int due = ref.watch(totalDueProvider);

    // Keeps the sync controller alive for the whole session. It is the only
    // thing that starts a background pass, and the shell is the one widget
    // that is always mounted, so listening here is what makes syncing
    // invisible to the user instead of a button in Settings. A listener rather
    // than a watch, so a sync starting never rebuilds the tab bar.
    ref.listen<SyncState>(syncControllerProvider, (SyncState? _, SyncState __) {});

    // Reminders follow the workload, not a timer: whenever the amount of due
    // work changes the schedule is rebuilt a couple of seconds later, which
    // collapses a whole review session into a single reschedule.
    ref.listen<int>(totalDueProvider, (int? _, int __) {
      ref.read(reminderCoordinatorProvider).schedule();
    });

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: navigationShell),
          if (!keyboardOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: GlassTabBar.reservedHeight + 6,
              child: const OfflineBanner(),
            ),
          if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassTabBar(
                currentIndex: navigationShell.currentIndex,
                dueCount: due,
                onSelect: (int index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
                onCreate: () {
                  if (!ensureCanCreate(context, ref)) {
                    return;
                  }
                  showCreateSheet(context);
                },
              ),
            ),
        ],
      ),
    );
  }
}
