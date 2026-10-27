import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../data/content_providers.dart';
import '../../domain/models.dart';
import 'editor_common.dart';

/// Opens the "new card" sheet. Pass [deckId] to add to a specific deck,
/// otherwise the sheet lets the user pick one.
Future<void> showCardEditorSheet(
  BuildContext context, {
  String? deckId,
}) async {
  final int? added = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext sheet) => _CardEditorSheet(initialDeckId: deckId),
  );
  if (added != null && added > 0 && context.mounted) {
    showAppMessage(
      context,
      added == 1 ? 'تمت إضافة البطاقة' : 'تمت إضافة $added بطاقات',
    );
  }
}

/// Opens the editor on an existing card. Returns the updated card when saved.
///
/// The deck is intentionally locked: moving a card between decks is a separate
/// operation, and changing `deck_id` from a review session would be surprising.
Future<ReviewCard?> showCardEditSheet(BuildContext context, ReviewCard card) {
  return showModalBottomSheet<ReviewCard>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext sheet) => _CardEditorSheet(editCard: card),
  );
}

class _CardEditorSheet extends ConsumerStatefulWidget {
  const _CardEditorSheet({this.initialDeckId, this.editCard});

  final String? initialDeckId;
  final ReviewCard? editCard;

  @override
  ConsumerState<_CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends ConsumerState<_CardEditorSheet> {
  final TextEditingController _front = TextEditingController();
  final TextEditingController _back = TextEditingController();
  final TextEditingController _hint = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final FocusNode _frontFocus = FocusNode();

  String? _deckId;
  String? _error;
  bool _saving = false;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    final ReviewCard? card = widget.editCard;
    _deckId = card?.deckId ?? widget.initialDeckId;
    if (card != null) {
      _front.text = card.front;
      _back.text = card.back;
      _hint.text = card.hint ?? '';
      _note.text = card.note ?? '';
      _tags.text = card.tags.join('، ');
    }
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _hint.dispose();
    _note.dispose();
    _tags.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  /// Saves the card. Returns true when it was stored.
  Future<bool> _store() async {
    final String? deckId = _deckId;
    if (deckId == null) {
      setState(() => _error = 'اختر المجموعة أولاً');
      return false;
    }
    if (_front.text.trim().isEmpty || _back.text.trim().isEmpty) {
      setState(() => _error = 'اكتب وجه البطاقة وإجابتها');
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.editCard != null) {
        await ref
            .read(contentRepositoryProvider)
            .updateCard(
              cardId: widget.editCard!.id,
              front: _front.text,
              back: _back.text,
              hint: _hint.text,
              note: _note.text,
              tags: parseTags(_tags.text),
            );
      } else {
        await ref
            .read(contentRepositoryProvider)
            .addCard(
              deckId: deckId,
              front: _front.text,
              back: _back.text,
              hint: _hint.text,
              note: _note.text,
              tags: parseTags(_tags.text),
            );
        _added++;
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر حفظ البطاقة. حاول مرة أخرى.');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveAndClose() async {
    if (!await _store() || !mounted) {
      return;
    }
    final ReviewCard? card = widget.editCard;
    if (card == null) {
      Navigator.of(context).pop(_added);
      return;
    }
    Navigator.of(context).pop(
      ReviewCard(
        id: card.id,
        deckId: card.deckId,
        front: _front.text.trim(),
        back: _back.text.trim(),
        hint: _hint.text.trim().isEmpty ? null : _hint.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        tags: parseTags(_tags.text),
        phase: card.phase,
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    if (await _store() && mounted) {
      _front.clear();
      _back.clear();
      _hint.clear();
      _note.clear();
      _frontFocus.requestFocus();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.editCard != null;

    // Cards live in sub-decks only: main decks are containers for sub-decks.
    final List<DeckNode> decks = flattenDeckForest(
      ref.watch(deckForestProvider),
    ).where((DeckNode deck) => deck.canHoldCards).toList(growable: false);

    if (!editing && decks.isEmpty) {
      return const EditorSheetFrame(
        title: 'بطاقة جديدة',
        child: Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'البطاقات تُضاف داخل المجموعات الفرعية. أنشئ مجموعة رئيسية، '
            'ثم أضف إليها مجموعة فرعية، ثم أضف بطاقاتك.',
            style: TextStyle(height: 1.7),
          ),
        ),
      );
    }

    DeckNode? selected;
    for (final DeckNode deck in decks) {
      if (deck.id == _deckId) {
        selected = deck;
      }
    }

    final String? subtitleDeckId =
        widget.editCard?.deckId ?? widget.initialDeckId;

    return EditorSheetFrame(
      title: editing ? 'تعديل البطاقة' : 'بطاقة جديدة',
      subtitle: subtitleDeckId != null && selected != null
          ? 'في: ${selected.title}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!editing && widget.initialDeckId == null) ...<Widget>[
            const EditorLabel('المجموعة'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: editorFieldFill(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selected?.id,
                  hint: const Text('اختر المجموعة'),
                  borderRadius: BorderRadius.circular(20),
                  items: <DropdownMenuItem<String>>[
                    for (final DeckNode deck in decks)
                      DropdownMenuItem<String>(
                        value: deck.id,
                        child: Text(
                          '${'— ' * deck.depth}${deck.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (String? value) => setState(() {
                    _deckId = value;
                    _error = null;
                  }),
                ),
              ),
            ),
          ],
          const EditorLabel('وجه البطاقة'),
          TextField(
            controller: _front,
            focusNode: _frontFocus,
            autofocus: !editing,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            decoration: editorDecoration(
              context,
              hint: 'السؤال أو المصطلح',
              multiline: true,
            ),
          ),
          const EditorLabel('الإجابة'),
          TextField(
            controller: _back,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            decoration: editorDecoration(
              context,
              hint: 'الجواب الصحيح',
              multiline: true,
            ),
          ),
          const EditorLabel('تلميح (اختياري)'),
          TextField(
            controller: _hint,
            decoration: editorDecoration(context, hint: 'يظهر قبل الإجابة'),
          ),
          const EditorLabel('ملاحظتي (اختياري)'),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: editorDecoration(
              context,
              hint: 'تظهر مع الإجابة',
              multiline: true,
            ),
          ),
          const EditorLabel('الوسوم (اختياري)'),
          TextField(
            controller: _tags,
            decoration: editorDecoration(context, hint: 'افصل بينها بفاصلة'),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          ] else if (!editing && _added > 0) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 16,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'أُضيفت $_added في هذه الجلسة',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (editing)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _saveAndClose,
                child: const Text('حفظ التعديلات'),
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _saveAndContinue,
                    child: const Text('حفظ وإضافة أخرى'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _saveAndClose,
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
