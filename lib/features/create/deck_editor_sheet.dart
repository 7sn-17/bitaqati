import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';
import 'editor_common.dart';

/// Opens the deck sheet. With [deck] it edits that deck's title, colour and
/// icon; without it, the sheet creates a new deck.
/// Returns the created or edited deck id, or null when dismissed.
Future<String?> showDeckEditorSheet(
  BuildContext context, {
  DeckNode? deck,
}) async {
  final String? id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext sheet) => _DeckEditorSheet(deck: deck),
  );
  if (id != null && context.mounted) {
    showAppMessage(
      context,
      deck != null ? 'تم تحديث المجموعة.' : 'تم إنشاء المجموعة',
    );
  }
  return id;
}

class _DeckEditorSheet extends ConsumerStatefulWidget {
  const _DeckEditorSheet({this.deck});

  final DeckNode? deck;

  @override
  ConsumerState<_DeckEditorSheet> createState() => _DeckEditorSheetState();
}

class _DeckEditorSheetState extends ConsumerState<_DeckEditorSheet> {
  late final TextEditingController _title;
  int _colorIndex = 0;
  String _iconKey = 'layers';
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.deck != null;

  @override
  void initState() {
    super.initState();
    final DeckNode? deck = widget.deck;
    _title = TextEditingController(text: deck?.title ?? '');
    _iconKey = deck?.iconKey ?? 'layers';
    if (deck != null) {
      final String hex = colorToHex(deck.color);
      final int index = kDeckColors.indexWhere(
        (Color color) => colorToHex(color) == hex,
      );
      _colorIndex = index < 0 ? 0 : index;
    }
  }

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
      final DeckNode? editing = widget.deck;
      if (editing != null) {
        await ref
            .read(contentRepositoryProvider)
            .updateDeck(
              deckId: editing.id,
              title: title,
              colorHex: colorToHex(kDeckColors[_colorIndex]),
              icon: _iconKey,
            );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(editing.id);
        return;
      }
      final String id = await ref
          .read(contentRepositoryProvider)
          .createDeck(
            title: title,
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
        _error = _isEditing
            ? 'تعذّر تحديث المجموعة. حاول مرة أخرى.'
            : 'تعذّر إنشاء المجموعة. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color chosen = kDeckColors[_colorIndex];
    // The preview is painted in the deck colour, and the palette runs from
    // near-black forest to pale sand, so the foreground cannot be a fixed
    // white. It is measured against the middle of the gradient, which is the
    // lightest point a deep tone reaches and the darkest a pale one does.
    final Color ink = onDeckColor(Color.lerp(chosen, Colors.black, 0.11)!);
    final IconData icon = kDeckIcons[_iconKey] ?? Icons.layers_rounded;
    final String previewTitle = _title.text.trim();

    return EditorSheetFrame(
      title: _isEditing ? 'تعديل المجموعة' : 'مجموعة جديدة',
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
                    color: ink.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: ink, size: 26),
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
                          color: ink.withValues(
                            alpha: previewTitle.isEmpty ? 0.55 : 1,
                          ),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isEditing ? 'تعديل' : 'جديدة',
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.72),
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
              hint: 'مثال: ملاحظاتي · الفصل الأول',
              errorText: _error,
            ),
          ),
          const EditorLabel('اللون', hint: 'اسحب للمزيد'),
          _SwatchGrid(
            selected: _colorIndex,
            onSelect: (int index) => setState(() => _colorIndex = index),
          ),
          const EditorLabel('الأيقونة', hint: 'اسحب للمزيد'),
          _IconGrid(
            selected: _iconKey,
            tint: chosen,
            onSelect: (String key) => setState(() => _iconKey = key),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'جارٍ الحفظ'
                    : _isEditing
                    ? 'حفظ التعديلات'
                    : 'إنشاء المجموعة',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour picker for the deck sheet.
///
/// The palette holds 42 tones, so the swatches scroll inside a three-row
/// window instead of growing a wrap that would push the save button off the
/// sheet. Every swatch carries a hairline outline, because the pale family
/// would otherwise vanish on a white sheet, and the tick is drawn with
/// [onDeckColor] so it reads on both families.
class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const double _size = 40;
  static const double _gap = 9;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size * 3 + _gap * 2,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (int index = 0; index < kDeckColors.length; index++)
              Semantics(
                button: true,
                selected: index == selected,
                label: 'اللون ${index + 1}',
                child: GestureDetector(
                  onTap: () => onSelect(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: _size,
                    height: _size,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index == selected
                            ? context.colors.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kDeckColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.07),
                        ),
                      ),
                      child: index == selected
                          ? Icon(
                              CupertinoIcons.checkmark_alt,
                              size: 15,
                              color: onDeckColor(kDeckColors[index]),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon picker for the deck sheet.
///
/// Same shape as [_SwatchGrid]: the set is 79 icons, so it scrolls inside a
/// fixed three-row window. The chosen tile is painted in the deck colour and
/// its glyph in the measured ink, which keeps a pale deck readable.
class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.selected,
    required this.tint,
    required this.onSelect,
  });

  final String selected;
  final Color tint;
  final ValueChanged<String> onSelect;

  static const double _size = 44;
  static const double _gap = 9;

  @override
  Widget build(BuildContext context) {
    final Color onTint = onDeckColor(tint);
    return SizedBox(
      height: _size * 3 + _gap * 2,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (final MapEntry<String, IconData> entry in kDeckIcons.entries)
              Semantics(
                button: true,
                selected: entry.key == selected,
                label: entry.key,
                child: GestureDetector(
                  onTap: () => onSelect(entry.key),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      color: entry.key == selected
                          ? tint
                          : editorFieldFill(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: entry.key == selected
                            ? tint
                            : context.colors.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      boxShadow: entry.key == selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: tint.withValues(alpha: 0.24),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      entry.value,
                      size: 21,
                      color: entry.key == selected
                          ? onTint
                          : context.colors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
