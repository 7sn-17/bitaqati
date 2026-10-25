import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_surface.dart';
import '../../core/widgets/editor_sheets.dart';
import '../../core/widgets/floating_nav_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final CreateAction? action = await showCreateActions(
      context,
      inDeck: false,
    );
    if (!context.mounted || action == null) {
      return;
    }
    if (action != CreateAction.deck) {
      return;
    }
    final DeckDraft? draft = await showDeckEditor(context);
    if (draft == null || !context.mounted) {
      return;
    }
    try {
      final String id = await ref
          .read(contentRepositoryProvider)
          .createDeck(
            title: draft.title,
            description: draft.description,
            colorHex: draft.colorHex,
            iconKey: draft.iconKey,
            tags: draft.tags,
            privacy: draft.privacy,
          );
      ref.invalidate(catalogProvider);
      if (context.mounted) {
        showAppSnack(context, context.strings.deckCreated);
        context.go('/deck/$id');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnack(context, error.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              currentIndex: navigationShell.currentIndex,
              onSelect: (int index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              onCreate: () => _create(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
