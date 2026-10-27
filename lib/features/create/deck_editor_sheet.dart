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
  int _colorIndex = 0;
  String _iconKey = 'layers';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
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
    final IconData icon = kDeckIcons[_iconKey] ?? Icons.layers_rounded;
    final String previewTitle = _title.text.trim();

    return EditorSheetFrame(
      title: isSub ? 'مجموعة فرعية جديدة' : 'مجموعة جديدة',
      subtitle: widget.parentTitle == null
          ? null
          : 'داخل: ${widget.parentTitle}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  chosen,
                  Color.lerp(chosen, Colors.black, 0.22) ?? chosen,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: chosen.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        previewTitle.isEmpty ? 'اسم المجموعة' : previewTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: previewTitle.isEmpty ? 0.55 : 1,
                          ),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isSub ? 'مجموعة فرعية' : 'مجموعة رئيسية',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const EditorLabel('الاسم'),
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 160,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _error = null),
            decoration: editorDecoration(
              context,
              hint: 'مثال: الفيزياء · الحركة',
              errorText: _error,
            ),
          ),
          const EditorLabel('اللون'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (int index = 0; index < kDeckColors.length; index++)
                Semantics(
                  button: true,
                  selected: index == _colorIndex,
                  label: 'اللون ${index + 1}',
                  child: GestureDetector(
                    onTap: () => setState(() => _colorIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: index == _colorIndex
                              ? context.colors.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: kDeckColors[index],
                          shape: BoxShape.circle,
                        ),
                        child: index == _colorIndex
                            ? const Icon(
                                CupertinoIcons.checkmark_alt,
                                size: 17,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
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
                      border: Border.all(
                        color: entry.key == _iconKey
                            ? chosen
                            : context.colors.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      boxShadow: entry.key == _iconKey
                          ? <BoxShadow>[
                              BoxShadow(
                                color: chosen.withValues(alpha: 0.24),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
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
