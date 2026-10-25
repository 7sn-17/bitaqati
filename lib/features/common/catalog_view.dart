import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_surface.dart';
import '../../domain/models.dart';

class CatalogView extends ConsumerWidget {
  const CatalogView({required this.builder, super.key});

  final Widget Function(BuildContext context, Catalog catalog) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Catalog> state = ref.watch(catalogProvider);
    return state.when(
      data: (Catalog catalog) => builder(context, catalog),
      loading: () => const _CatalogLoading(),
      error: (Object error, StackTrace stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: context.strings.errorGeneric,
            body: error.toString(),
            action: FilledButton(
              onPressed: () => ref.invalidate(catalogProvider),
              child: Text(context.strings.retry),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

Future<void> refreshCatalog(WidgetRef ref) async {
  ref.invalidate(catalogProvider);
  await ref.read(catalogProvider.future);
}

Widget maxWidth(Widget child, {double width = kPageMaxWidth}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}
