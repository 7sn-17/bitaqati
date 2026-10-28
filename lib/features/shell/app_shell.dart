import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/guest_guard.dart';
import '../../core/notifications/reminder_providers.dart';
import '../../core/updates/update_providers.dart';
import '../../core/updates/update_service.dart';
import '../../core/widgets/glass_tab_bar.dart';
import '../../core/widgets/offline_banner.dart';
import '../../data/content_providers.dart';
import '../../data/sync_providers.dart';
import '../create/create_sheet.dart';
import '../updates/update_dialog.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// One prompt per launch. The shell is built once per cold start and lives
  /// for the whole session, so this flag is what keeps the dialog from
  /// reappearing as the user moves between tabs — while a fresh process always
  /// gets a fresh check.
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _promptForUpdate();
    });
  }

  /// Looks for a newer release in the background and offers it, once per
  /// launch.
  ///
  /// Deliberately late: the first frame, the first sync and the reminder
  /// refresh all matter more than a dialog, and a user who taps through in the
  /// first second should not have the screen covered.
  ///
  /// "Later" is remembered in memory only, so the offer comes back the next
  /// time the app is opened. It used to be written to disk, which quietly
  /// turned "later" into "never" for anyone who tapped it once.
  Future<void> _promptForUpdate() async {
    if (_prompted) {
      return;
    }
    _prompted = true;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    UpdateInfo? info;
    try {
      info = await ref.read(updateInfoProvider.future);
    } catch (error) {
      // check() reports failures as null rather than throwing, but a provider
      // that dies must not take the launch prompt down with it.
      debugPrint('[update] launch check threw: $error');
      return;
    }
    if (!mounted) {
      return;
    }
    debugPrint(
      '[update] launch prompt · hasUpdate=${info?.hasUpdate} '
      '· latest=${info?.latestVersion} · fromCache=${info?.fromCache}',
    );
    if (info == null || !info.hasUpdate) {
      return;
    }
    if (ref.read(updateDismissedProvider) == info.latestVersion) {
      return;
    }
    await showUpdateDialog(context, info);
  }

  @override
  Widget build(BuildContext context) {
    final StatefulNavigationShell navigationShell = widget.navigationShell;
    // The floating bar would ride above the keyboard, so hide it while typing.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final int due = ref.watch(totalDueProvider);

    // Keeps the sync controller alive for the whole session. It is the only
    // thing that starts a background pass, and the shell is the one widget
    // that is always mounted, so listening here is what makes syncing
    // invisible to the user instead of a button in Settings. A listener rather
    // than a watch, so a sync starting never rebuilds the tab bar.
    ref.listen<SyncState>(
      syncControllerProvider,
      (SyncState? _, SyncState __) {},
    );

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
