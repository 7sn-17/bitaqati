import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/glass_tab_bar.dart';
import '../../data/content_providers.dart';
import '../create/create_sheet.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The floating bar would ride above the keyboard, so hide it while typing.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final int due = ref.watch(totalDueProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: navigationShell),
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
                onCreate: () => showCreateSheet(context),
              ),
            ),
        ],
      ),
    );
  }
}
