import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';
import 'editor_common.dart';

/// Opens the "new deck" sheet. With [parentId] it creates a sub-deck.
/// Returns the new deck id, or null when the sheet was dismissed.
Future<String?> showDeckEditorSheet(
  BuildContext context, {
  String? parentId,
  String? parentTitle,
}) async {
  final String? id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext sheet) =>
        _DeckEditorSheet(parentId: parentId, parentTitle: parentTitle),
  );
  if (id != null && context.mounted) {
    showAppMessage(
      context,
      parentId == null ? 'تم إنشاء المجموعة' : 'تمت إضافة المجموعة الفرعية',
    );
  }
  return id;
}

class _DeckEditorSheet extends ConsumerStatefulWidget {
  const _DeckEditorSheet({this.parentId, this.parentTitle});

  final String? parentId;
  final String? parentTitle;

  @override
  ConsumerState<_DeckEditorSheet> createState() => _DeckEditorSheetState();
}

class _DeckEditorSheetState extends ConsumerState<_DeckEditorSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  int _colorIndex = 0;
  String _iconKey = 'layers';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'اكتب اسم المجموعة');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final String id = await ref
          .read(contentRepositoryProvider)
          .createDeck(
            title: title,
            parentId: widget.parentId,
            colorHex: colorToHex(kDeckColors[_colorIndex]),
            icon: _iconKey,
            tags: parseTags(_tags.text),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'تعذّر إنشاء المجموعة. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSub = widget.parentId != null;
    final Color chosen = kDeckColors[_colorIndex];

    return EditorSheetFrame(
      title: isSub ? 'مجموعة فرعية جديدة' : 'مجموعة جديدة',
      subtitle: widget.parentTitle == null
          ? null
          : 'داخل: ${widget.parentTitle}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const EditorLabel('الاسم'),
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 160,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            decoration: editorDecoration(
              context,
              hint: 'مثال: الفيزياء · الحركة',
              errorText: _error,
            ),
          ),
          const EditorLabel('الوسوم (اختياري)'),
          TextField(
            controller: _tags,
            textInputAction: TextInputAction.done,
            decoration: editorDecoration(
              context,
              hint: 'افصل بينها بفاصلة، مثال: الفيزياء، الفصل الأول',
            ),
          ),
          const EditorLabel('اللون'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (int index = 0; index < kDeckColors.length; index++)
                GestureDetector(
                  onTap: () => setState(() => _colorIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kDeckColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index == _colorIndex
                            ? context.colors.onSurface
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                    child: index == _colorIndex
                        ? const Icon(
                            CupertinoIcons.checkmark_alt,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const EditorLabel('الأيقونة'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final MapEntry<String, IconData> entry in kDeckIcons.entries)
                GestureDetector(
                  onTap: () => setState(() => _iconKey = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: entry.key == _iconKey
                          ? chosen
                          : editorFieldFill(context),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      entry.value,
                      size: 22,
                      color: entry.key == _iconKey
                          ? Colors.white
                          : context.colors.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جارٍ الحفظ' : 'إنشاء المجموعة'),
            ),
          ),
        ],
      ),
    );
  }
}
