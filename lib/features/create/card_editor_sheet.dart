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
Future<void> showCardEditorSheet(BuildContext context, {String? deckId}) async {
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
Future<ReviewCard?> showCardEditSheet(BuildContext context, ReviewCard card) {
  return showModalBottomSheet<ReviewCard>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (BuildContext sheet) => _CardEditorSheet(editCard: card),
  );
}

enum _CardKind { basic, cloze, occlusion }

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
  final TextEditingController _image = TextEditingController();
  final FocusNode _frontFocus = FocusNode();
  final FocusNode _backFocus = FocusNode();

  String? _deckId;
  String? _error;
  bool _saving = false;
  int _added = 0;
  _CardKind _kind = _CardKind.basic;

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
      switch (card.type) {
        case 'cloze':
          _kind = _CardKind.cloze;
        case 'occlusion':
          _kind = _CardKind.occlusion;
          final RegExpMatch? match = RegExp(
            r'^!\[[^\]]*\]\(([^)]+)\)$',
          ).firstMatch(card.front);
          _image.text = match?.group(1) ?? card.front;
        default:
          _kind = _CardKind.basic;
      }
    }
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _hint.dispose();
    _note.dispose();
    _tags.dispose();
    _image.dispose();
    _frontFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  bool get _editing => widget.editCard != null;

  String get _type {
    switch (_kind) {
      case _CardKind.basic:
        return 'basic';
      case _CardKind.cloze:
        return 'cloze';
      case _CardKind.occlusion:
        return 'occlusion';
    }
  }

  TextEditingController get _activeField =>
      _backFocus.hasFocus ? _back : _front;

  Future<bool> _store() async {
    final String? deckId = _deckId;
    if (deckId == null) {
      setState(() => _error = 'اختر المجموعة أولاً');
      return false;
    }
    String front = _front.text.trim();
    String back = _back.text.trim();
    if (_kind == _CardKind.occlusion) {
      final String image = _image.text.trim();
      if (image.isEmpty) {
        setState(() => _error = 'أضف رابط صورة للتغطية البصرية');
        return false;
      }
      front = '![تغطية]($image)';
      if (back.isEmpty) {
        back = 'تغطية بصرية';
      }
    }
    if (front.isEmpty || back.isEmpty) {
      setState(() => _error = 'اكتب وجه البطاقة وإجابتها');
      return false;
    }
    if (_kind == _CardKind.cloze &&
        !RegExp(r'\{\{c\d+::').hasMatch(front)) {
      setState(
        () => _error = 'أضف فراغاً مثل {{c1::الإجابة}} داخل النص',
      );
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await ref
            .read(contentRepositoryProvider)
            .updateCard(
              cardId: widget.editCard!.id,
              front: front,
              back: back,
              hint: _hint.text,
              note: _note.text,
              tags: parseTags(_tags.text),
              type: _type,
            );
      } else {
        await ref
            .read(contentRepositoryProvider)
            .addCard(
              deckId: deckId,
              front: front,
              back: back,
              hint: _hint.text,
              note: _note.text,
              tags: parseTags(_tags.text),
              type: _type,
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
    final String front = _kind == _CardKind.occlusion
        ? '![تغطية](${_image.text.trim()})'
        : _front.text.trim();
    final String back = _kind == _CardKind.occlusion && _back.text.trim().isEmpty
        ? 'تغطية بصرية'
        : _back.text.trim();
    Navigator.of(context).pop(
      ReviewCard(
        id: card.id,
        deckId: card.deckId,
        front: front,
        back: back,
        hint: _hint.text.trim().isEmpty ? null : _hint.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        tags: parseTags(_tags.text),
        phase: card.phase,
        type: _type,
        due: card.due,
        lapses: card.lapses,
        scheduledDays: card.scheduledDays,
        suspended: card.suspended,
        favorite: card.favorite,
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    if (await _store() && mounted) {
      _front.clear();
      _back.clear();
      _hint.clear();
      _note.clear();
      _tags.clear();
      _image.clear();
      _frontFocus.requestFocus();
      setState(() {});
    }
  }

  void _insertAround(String prefix, String suffix, String placeholder) {
    final TextEditingController controller = _activeField;
    final TextSelection selection = controller.selection;
    final String text = controller.text;
    final int start = selection.isValid ? selection.start : text.length;
    final int end = selection.isValid ? selection.end : text.length;
    final String selected = text.substring(start, end);
    final String body = selected.isEmpty ? placeholder : selected;
    final String inserted = '$prefix$body$suffix';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    setState(() {});
  }

  Future<void> _insertAttachment({required bool image}) async {
    final TextEditingController url = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(image ? 'إرفاق صورة' : 'إرفاق صوت'),
        content: TextField(
          controller: url,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: image ? 'https://…/image.jpg' : 'https://…/audio.mp3',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(url.text),
            child: const Text('إرفاق'),
          ),
        ],
      ),
    );
    url.dispose();
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }
    _insertAround(
      image ? '![' : '[',
      image ? ']($trimmed)' : ']($trimmed)',
      image ? 'صورة' : 'صوت',
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DeckNode> decks = flattenDeckForest(
      ref.watch(deckForestProvider),
    ).where((DeckNode deck) => deck.canHoldCards).toList(growable: false);

    if (!_editing && decks.isEmpty) {
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
    final String previewFront = _kind == _CardKind.occlusion
        ? (_image.text.trim().isEmpty
              ? ''
              : '![تغطية](${_image.text.trim()})')
        : _front.text;
    final List<String> liveTags = parseTags(_tags.text);

    return EditorSheetFrame(
      title: _editing ? 'تعديل البطاقة' : 'بطاقة جديدة',
      subtitle: subtitleDeckId != null && selected != null
          ? 'في: ${selected.title}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!_editing && widget.initialDeckId == null) ...<Widget>[
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
          const SizedBox(height: 14),
          _CardKindTabs(
            selected: _kind,
            onChanged: (value) => setState(() {
              _kind = value;
              _error = null;
            }),
          ),
          if (_kind == _CardKind.occlusion) ...<Widget>[
            const EditorLabel('صورة التغطية'),
            TextField(
              controller: _image,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.url,
              decoration: editorDecoration(
                context,
                hint: 'https://…/image.jpg',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(
                  alpha: context.isDark ? 0.15 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    CupertinoIcons.rectangle_on_rectangle,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أضف رابط صورة واضحة مع الإجابة النصية. '
                      'تُعرض الصورة في المراجعة كبطاقة تغطية بصرية.',
                      style: context.texts.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const EditorLabel('الإجابة أو التعليق'),
            TextField(
              controller: _back,
              minLines: 2,
              maxLines: 4,
              decoration: editorDecoration(
                context,
                hint: 'ما الذي يجب أن يتذكره المتعلّم؟',
                multiline: true,
              ),
            ),
          ] else ...<Widget>[
            const EditorLabel('وجه البطاقة'),
            _FormattingToolbar(
              onBold: () => _insertAround('**', '**', 'نص عريض'),
              onItalic: () => _insertAround('_', '_', 'نص مائل'),
              onMath: () => _insertAround(r'$', r'$', 'x^2'),
              onImage: () => _insertAttachment(image: true),
              onAudio: () => _insertAttachment(image: false),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _front,
              focusNode: _frontFocus,
              autofocus: !_editing,
              minLines: 3,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.newline,
              decoration: editorDecoration(
                context,
                hint: _kind == _CardKind.cloze
                    ? 'اكتب النص وضع الفراغ: {{c1::الإجابة}}'
                    : 'اكتب السؤال أو المفهوم…',
                multiline: true,
              ),
            ),
            const EditorLabel('الإجابة'),
            _FormattingToolbar(
              onBold: () => _insertAround('**', '**', 'نص عريض'),
              onItalic: () => _insertAround('_', '_', 'نص مائل'),
              onMath: () => _insertAround(r'$', r'$', 'x^2'),
              onImage: () => _insertAttachment(image: true),
              onAudio: () => _insertAttachment(image: false),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _back,
              focusNode: _backFocus,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.newline,
              decoration: editorDecoration(
                context,
                hint: _kind == _CardKind.cloze
                    ? 'شرح إضافي أو الإجابة الكاملة…'
                    : 'اكتب الإجابة…',
                multiline: true,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _LivePreview(
            front: previewFront,
            back: _back.text,
            kind: _kind,
          ),
          const EditorLabel('الوسوم'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: editorFieldFill(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  CupertinoIcons.tag,
                  size: 17,
                  color: context.texts.bodySmall?.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tags,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'أضف وسوماً مفصولة بفاصلة',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (liveTags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String tag in liveTags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft.withValues(
                        alpha: context.isDark ? 0.18 : 1,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              'خيارات إضافية',
              style: context.texts.labelLarge,
            ),
            iconColor: context.colors.primary,
            collapsedIconColor: context.texts.bodySmall?.color,
            children: <Widget>[
              const EditorLabel('تلميح'),
              TextField(
                controller: _hint,
                decoration: editorDecoration(
                  context,
                  hint: 'تلميح يظهر عند الحاجة',
                ),
              ),
              const EditorLabel('ملاحظة'),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: editorDecoration(
                  context,
                  hint: 'ملاحظة شخصية أو مصدر',
                  multiline: true,
                ),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_editing)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _saveAndClose,
                child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التعديلات'),
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
                    child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CardKindTabs extends StatelessWidget {
  const _CardKindTabs({required this.selected, required this.onChanged});

  final _CardKind selected;
  final ValueChanged<_CardKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          _KindTab(
            label: 'أساسية',
            icon: CupertinoIcons.rectangle_stack,
            selected: selected == _CardKind.basic,
            onTap: () => onChanged(_CardKind.basic),
          ),
          _KindTab(
            label: 'ملء فراغ',
            icon: CupertinoIcons.textformat_abc,
            selected: selected == _CardKind.cloze,
            onTap: () => onChanged(_CardKind.cloze),
          ),
          _KindTab(
            label: 'تغطية',
            icon: CupertinoIcons.rectangle_on_rectangle,
            selected: selected == _CardKind.occlusion,
            onTap: () => onChanged(_CardKind.occlusion),
          ),
        ],
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (context.isDark ? AppColors.darkSurfaceHigh : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                size: 17,
                color: selected
                    ? context.colors.primary
                    : context.texts.bodySmall?.color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? context.colors.primary
                      : context.texts.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormattingToolbar extends StatelessWidget {
  const _FormattingToolbar({
    required this.onBold,
    required this.onItalic,
    required this.onMath,
    required this.onImage,
    required this.onAudio,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onMath;
  final VoidCallback onImage;
  final VoidCallback onAudio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          _ToolButton(
            icon: CupertinoIcons.bold,
            tooltip: 'عريض',
            onTap: onBold,
          ),
          _ToolButton(
            icon: CupertinoIcons.italic,
            tooltip: 'مائل',
            onTap: onItalic,
          ),
          _ToolButton(
            icon: CupertinoIcons.function,
            tooltip: 'معادلة',
            onTap: onMath,
          ),
          const Spacer(),
          _ToolButton(
            icon: CupertinoIcons.photo,
            tooltip: 'صورة',
            onTap: onImage,
          ),
          _ToolButton(
            icon: CupertinoIcons.mic,
            tooltip: 'صوت',
            onTap: onAudio,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 17,
            color: context.colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.front,
    required this.back,
    required this.kind,
  });

  final String front;
  final String back;
  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            context.colors.surfaceContainerHighest,
            context.colors.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.eye,
                size: 14,
                color: context.colors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                'معاينة مباشرة',
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _PreviewMarkup(
              text: front,
              kind: kind,
              placeholder: 'سيظهر وجه البطاقة هنا',
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.darkCanvas : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _PreviewMarkup(
              text: back,
              kind: _CardKind.basic,
              placeholder: 'ستظهر الإجابة هنا',
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMarkup extends StatelessWidget {
  const _PreviewMarkup({
    required this.text,
    required this.kind,
    required this.placeholder,
  });

  final String text;
  final _CardKind kind;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return Text(
        placeholder,
        style: context.texts.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final RegExpMatch? image = RegExp(
      r'^!\[[^\]]*\]\(([^)]+)\)$',
    ).firstMatch(trimmed);
    if (image != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              image.group(1)!,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 80,
                alignment: Alignment.center,
                color: context.colors.surfaceContainerHighest,
                child: const Icon(CupertinoIcons.photo, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            image.group(1)!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall?.copyWith(fontSize: 9),
          ),
        ],
      );
    }
    final RegExpMatch? audio = RegExp(
      r'^\[(?:صوت|sound)[^\]]*\]\(([^)]+)\)$',
    ).firstMatch(trimmed);
    if (audio != null) {
      return Row(
        children: <Widget>[
          const Icon(
            CupertinoIcons.play_circle_fill,
            size: 22,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              audio.group(1)!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ),
        ],
      );
    }
    return Text.rich(
      TextSpan(
        children: _spans(context, trimmed, kind),
        style: context.texts.bodyMedium?.copyWith(height: 1.6),
      ),
    );
  }

  List<InlineSpan> _spans(
    BuildContext context,
    String value,
    _CardKind kind,
  ) {
    if (kind == _CardKind.cloze) {
      final List<InlineSpan> spans = <InlineSpan>[];
      final RegExp regex = RegExp(r'\{\{c\d+::(.*?)\}\}');
      int cursor = 0;
      for (final RegExpMatch match in regex.allMatches(value)) {
        if (match.start > cursor) {
          spans.add(TextSpan(text: value.substring(cursor, match.start)));
        }
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              backgroundColor: AppColors.accentSoft,
            ),
          ),
        );
        cursor = match.end;
      }
      if (cursor < value.length) {
        spans.add(TextSpan(text: value.substring(cursor)));
      }
      return spans;
    }
    final RegExp regex = RegExp(r'(\*\*.*?\*\*|_.*?_|\$.*?\$)');
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in regex.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      final String token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('_')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              color: context.colors.primary,
              backgroundColor: AppColors.accentSoft.withValues(alpha: 0.5),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return spans;
  }
}
