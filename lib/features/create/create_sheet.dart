import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import 'card_editor_sheet.dart';
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
    showCardEditorSheet(parentContext);
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
