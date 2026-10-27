import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';
import 'deck_editor_sheet.dart';

Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext sheet) => _CreateSheet(parentContext: context),
  );
}

class _CreateSheet extends ConsumerWidget {
  const _CreateSheet({required this.parentContext});

  /// Context of the screen that opened the sheet. It stays mounted after the
  /// sheet closes, so editors and messages can be shown from it.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color surface = context.isDark
        ? AppColors.darkSurfaceHigh
        : Colors.white;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'ماذا تريد أن تنشئ؟',
                      style: context.texts.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Option(
                icon: CupertinoIcons.rectangle_stack,
                title: 'مجموعة جديدة',
                subtitle: 'نظّم بطاقاتك حسب المادة والفصل',
                onTap: () => _openDeckEditor(context, ref),
              ),
              _Option(
                icon: CupertinoIcons.doc_text,
                title: 'بطاقة جديدة',
                subtitle: 'أساسية، ملء فراغ، أو تغطية صورة',
                onTap: () => _openCardEditor(context, ref),
              ),
              _Option(
                icon: CupertinoIcons.arrow_down_circle,
                title: 'الاستيراد الذكي',
                subtitle: 'الصق نصاً كاملاً وحوّله إلى بطاقات',
                onTap: () => _openSmartImport(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDeckEditor(BuildContext context, WidgetRef ref) {
    final bool allowed = ref.read(authServiceProvider).currentUser != null;
    Navigator.of(context).pop();
    if (!allowed) {
      showAppMessage(
        parentContext,
        'إنشاء المجموعات والبطاقات متاح للحسابات. '
        'سجّل الدخول من الإعدادات بحساب Google لحفظ بطاقاتك ومزامنتها.',
        kind: AppMessageKind.info,
      );
      return;
    }
    showDeckEditorSheet(parentContext);
  }

  void _openCardEditor(BuildContext context, WidgetRef ref) {
    final bool allowed = ref.read(authServiceProvider).currentUser != null;
    Navigator.of(context).pop();
    if (!allowed) {
      showAppMessage(
        parentContext,
        'إنشاء المجموعات والبطاقات متاح للحسابات. '
        'سجّل الدخول من الإعدادات بحساب Google لحفظ بطاقاتك ومزامنتها.',
        kind: AppMessageKind.info,
      );
      return;
    }
    _pushCardEditor(parentContext);
  }

  void _openSmartImport(BuildContext context, WidgetRef ref) {
    final bool allowed = ref.read(authServiceProvider).currentUser != null;
    Navigator.of(context).pop();
    if (!allowed) {
      showAppMessage(
        parentContext,
        'الاستيراد متاح للحسابات. سجّل الدخول من الإعدادات بحساب Google.',
        kind: AppMessageKind.info,
      );
      return;
    }
    _pickDeckForImport(parentContext, ref);
  }

  /// Importing needs a destination. One deck goes straight there; several ask
  /// which one, because putting a hundred cards in the wrong deck is worse than
  /// one extra tap.
  Future<void> _pickDeckForImport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final List<DeckNode> decks = ref.read(allDecksProvider);
    if (decks.isEmpty) {
      showAppMessage(
        context,
        'أنشئ مجموعة أولاً، ثم استورد بطاقاتك إليها.',
        kind: AppMessageKind.info,
      );
      return;
    }
    String target = decks.first.id;
    if (decks.length > 1) {
      final String? picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheet) => SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                  child: Text(
                    'استيراد إلى أي مجموعة؟',
                    style: context.texts.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final DeckNode node in decks)
                        ListTile(
                          leading: Icon(
                            kDeckIcons[node.iconKey] ?? CupertinoIcons.folder,
                            color: node.color,
                          ),
                          title: Text(node.title),
                          subtitle: Text('${node.cardCount} بطاقة'),
                          onTap: () => Navigator.of(sheet).pop(node.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (picked == null || !context.mounted) {
        return;
      }
      target = picked;
    }
    final String? message = await context.push<String>('/import-cards/$target');
    if (message != null && context.mounted) {
      showAppMessage(context, message);
    }
  }

  /// Opens the full-screen editor and reports the result on the screen that
  /// opened the sheet, which is still mounted.
  Future<void> _pushCardEditor(BuildContext context) async {
    final String? message = await context.push<String>('/create-card');
    if (message != null && context.mounted) {
      showAppMessage(context, message);
    }
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tile = context.colors.surfaceContainerHighest;
    final Color foreground = context.colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: context.texts.titleMedium),
                    const SizedBox(height: 1),
                    Text(subtitle, style: context.texts.bodySmall),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_back,
                size: 18,
                color: context.texts.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
