import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_markup.dart';
import '../../data/content_providers.dart';
import '../../data/media_upload.dart';
import '../../domain/models.dart';
import 'editor_common.dart';
import 'occlusion_editor.dart';

/// Full-screen card editor used for both "new card" and "edit card".
///
/// Replaces the old bottom sheet: the sheet could not hold a media toolbar,
/// a live preview and an occlusion canvas at the same time.
class CardEditorPage extends ConsumerStatefulWidget {
  const CardEditorPage({this.deckId, this.cardId, super.key});

  final String? deckId;
  final String? cardId;

  @override
  ConsumerState<CardEditorPage> createState() => _CardEditorPageState();
}

enum _CardKind { basic, cloze, occlusion }

class _CardEditorPageState extends ConsumerState<CardEditorPage> {
  final MarkupTextController _front = MarkupTextController();
  final MarkupTextController _back = MarkupTextController();
  final TextEditingController _hint = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _tagInput = TextEditingController();
  final FocusNode _frontFocus = FocusNode();
  final FocusNode _backFocus = FocusNode();
  final MediaUploadService _media = MediaUploadService();

  String? _deckId;
  String? _error;
  bool _saving = false;
  bool _uploading = false;
  bool _hydrated = false;
  _CardKind _kind = _CardKind.basic;
  List<String> _tags = <String>[];
  String? _imageUrl;
  List<OcclusionBox> _boxes = <OcclusionBox>[];

  bool get _editing => widget.cardId != null;

  @override
  void initState() {
    super.initState();
    _deckId = widget.deckId;
    _frontFocus.addListener(_onFocusChange);
    _backFocus.addListener(_onFocusChange);
    _front.addListener(_refresh);
    _back.addListener(_refresh);
    if (_editing) {
      _hydrate(notify: false);
    }
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _hint.dispose();
    _note.dispose();
    _tagInput.dispose();
    _frontFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Pulls the stored card into the controllers exactly once.
  void _hydrate({bool notify = true}) {
    if (_hydrated || _deckId == null) {
      return;
    }
    final List<ReviewCard> cards =
        ref.read(deckCardsProvider(_deckId!)).valueOrNull ??
        const <ReviewCard>[];
    ReviewCard? found;
    for (final ReviewCard card in cards) {
      if (card.id == widget.cardId) {
        found = card;
      }
    }
    if (found == null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted && !_hydrated) {
          _hydrate(notify: false);
        }
      });
      return;
    }
    _hydrated = true;
    _deckId = found.deckId;
    _front.text = found.front;
    _back.text = found.back;
    _hint.text = found.hint ?? '';
    _note.text = found.note ?? '';
    _tags = List<String>.of(found.tags);
    switch (found.type) {
      case 'cloze':
        _kind = _CardKind.cloze;
      case 'occlusion':
        _kind = _CardKind.occlusion;
        _imageUrl = found.front;
        final RegExpMatch? image = kImageRegex.firstMatch(found.front);
        if (image != null) {
          _imageUrl = image.group(2);
        }
        _boxes = occlusionBoxes(found.occlusion);
      default:
        _kind = _CardKind.basic;
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  MarkupTextController get _activeField =>
      _backFocus.hasFocus ? _back : _front;

  String get _typeName {
    switch (_kind) {
      case _CardKind.basic:
        return 'basic';
      case _CardKind.cloze:
        return 'cloze';
      case _CardKind.occlusion:
        return 'occlusion';
    }
  }

  // --------------------------------------------------------------- editing --

  /// Wraps or unwraps the selection with [open]/[close].
  void _toggleWrap(String open, String close, String placeholder) {
    final MarkupTextController controller = _activeField;
    final TextEditingValue value = controller.value;
    final String text = value.text;
    final TextSelection selection = value.selection;
    final int start = selection.isValid ? selection.start : text.length;
    final int end = selection.isValid ? selection.end : text.length;
    final String selected = text.substring(start, end);
    final String before = text.substring(0, start);
    final String after = text.substring(end);

    if (before.endsWith(open) && after.startsWith(close)) {
      final String next =
          before.substring(0, before.length - open.length) + selected + after.substring(close.length);
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: start - open.length,
          extentOffset: start - open.length + selected.length,
        ),
      );
      return;
    }
    if (selected.length >= open.length + close.length &&
        selected.startsWith(open) &&
        selected.endsWith(close)) {
      final String inner = selected.substring(
        open.length,
        selected.length - close.length,
      );
      controller.value = TextEditingValue(
        text: text.replaceRange(start, end, inner),
        selection: TextSelection(
          baseOffset: start,
          extentOffset: start + inner.length,
        ),
      );
      return;
    }
    final String body = selected.isEmpty ? placeholder : selected;
    final String inserted = open + body + close;
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: selected.isEmpty
          ? TextSelection(
              baseOffset: start + open.length,
              extentOffset: start + open.length + placeholder.length,
            )
          : TextSelection(
              baseOffset: start,
              extentOffset: start + inserted.length,
            ),
    );
  }

  Future<void> _attach({required bool image}) async {
    if (_uploading) {
      return;
    }
    setState(() => _uploading = true);
    try {
      final PickedMedia? media = image
          ? await _media.pickImage()
          : await _media.pickAudio();
      if (media == null) {
        return;
      }
      if (media.url.isEmpty) {
        setState(() => _error = 'تعذّر قراءة الملف المحدد.');
        return;
      }
      if (_kind == _CardKind.occlusion && media.isImage) {
        setState(() {
          _imageUrl = media.url;
          _error = null;
        });
        return;
      }
      final MarkupTextController controller = _activeField;
      final TextSelection selection = controller.selection;
      final int at = selection.isValid ? selection.end : controller.text.length;
      final String text = controller.text;
      final String prefix = at > 0 && !text.substring(0, at).endsWith('\n')
          ? '\n'
          : '';
      final String inserted = '$prefix${media.markup}\n';
      controller.value = TextEditingValue(
        text: text.replaceRange(at, at, inserted),
        selection: TextSelection.collapsed(offset: at + inserted.length),
      );
      if (!media.uploaded) {
        setState(
          () => _error =
              'تم إرفاق الملف محلياً. سيُرفع إلى السحابة عند توفر الاتصال.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر إرفاق الملف. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _addTag(String raw) {
    final List<String> parsed = parseTags(raw);
    if (parsed.isEmpty) {
      return;
    }
    setState(() {
      for (final String tag in parsed) {
        if (!_tags.contains(tag)) {
          _tags.add(tag);
        }
      }
      _tagInput.clear();
    });
  }

  // ---------------------------------------------------------------- saving --

  String? _validate() {
    if (_deckId == null) {
      return 'اختر المجموعة أولاً.';
    }
    switch (_kind) {
      case _CardKind.basic:
        if (_front.text.trim().isEmpty || _back.text.trim().isEmpty) {
          return 'اكتب وجه البطاقة وإجابتها.';
        }
      case _CardKind.cloze:
        if (_front.text.trim().isEmpty) {
          return 'اكتب نص البطاقة.';
        }
        if (clozeCount(_front.text) == 0) {
          return 'حدّد كلمة واضغط «فراغ» لتغليفها بـ {{c1::…}}.';
        }
      case _CardKind.occlusion:
        if (_imageUrl == null || _imageUrl!.isEmpty) {
          return 'اختر صورة للتغطية البصرية.';
        }
        if (_boxes.isEmpty) {
          return 'ارسم مستطيل تغطية واحداً على الأقل.';
        }
    }
    return null;
  }

  String _resolvedFront() {
    if (_kind == _CardKind.occlusion) {
      return '![تغطية](${_imageUrl ?? ''})';
    }
    return _front.text.trim();
  }

  String _resolvedBack() {
    final String back = _back.text.trim();
    if (back.isNotEmpty) {
      return back;
    }
    if (_kind == _CardKind.occlusion) {
      return 'تغطية بصرية';
    }
    if (_kind == _CardKind.cloze) {
      final RegExpMatch? first = kClozeRegex.firstMatch(_front.text);
      final String answer = first?.group(1)?.trim() ?? '';
      return answer.isEmpty ? 'بطاقة ملء فراغ' : answer;
    }
    return '';
  }

  Future<bool> _store() async {
    final String? problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final Map<String, Object?>? occlusion = _kind == _CardKind.occlusion
        ? occlusionPayload(_boxes)
        : null;
    try {
      if (_editing) {
        await ref
            .read(contentRepositoryProvider)
            .updateCard(
              cardId: widget.cardId!,
              front: _resolvedFront(),
              back: _resolvedBack(),
              hint: _hint.text,
              note: _note.text,
              tags: _tags,
              type: _typeName,
              occlusion: occlusion,
            );
      } else {
        await ref
            .read(contentRepositoryProvider)
            .addCard(
              deckId: _deckId!,
              front: _resolvedFront(),
              back: _resolvedBack(),
              hint: _hint.text,
              note: _note.text,
              tags: _tags,
              type: _typeName,
              occlusion: occlusion,
            );
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
    context.pop(_editing ? 'تم تحديث البطاقة.' : 'تمت إضافة البطاقة.');
  }

  Future<void> _saveAndContinue() async {
    if (!await _store() || !mounted) {
      return;
    }
    setState(() {
      _front.clear();
      _back.clear();
      _hint.clear();
      _note.clear();
      _tagInput.clear();
      _tags = <String>[];
      _imageUrl = null;
      _boxes = <OcclusionBox>[];
      _error = null;
    });
    _frontFocus.requestFocus();
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final List<DeckNode> decks = flattenDeckForest(
      ref.watch(deckForestProvider),
    ).where((DeckNode deck) => deck.canHoldCards).toList(growable: false);

    DeckNode? selected;
    for (final DeckNode deck in decks) {
      if (deck.id == _deckId) {
        selected = deck;
      }
    }

    if (!_editing && decks.isEmpty) {
      return Scaffold(
        appBar: AppBar(leading: _closeButton(context)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                CupertinoIcons.folder_badge_plus,
                size: 44,
                color: context.brandInk,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد مجموعة فرعية بعد',
                style: context.texts.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'البطاقات تُضاف داخل المجموعات الفرعية. أنشئ مجموعة رئيسية، '
                'ثم أضف إليها مجموعة فرعية، ثم أضف بطاقاتك.',
                style: context.texts.bodySmall?.copyWith(height: 1.8),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: _closeButton(context),
        title: Text(_editing ? 'تعديل البطاقة' : 'بطاقة جديدة'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: TextButton(
              onPressed: _saving ? null : _saveAndClose,
              child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
        children: <Widget>[
          if (selected != null)
            _DeckBanner(
              deck: selected,
              onChange: !_editing && widget.deckId == null
                  ? () => _pickDeck(decks)
                  : null,
            ),
          if (selected == null && !_editing) ...<Widget>[
            const SizedBox(height: 8),
            _PickerRow(
              label: 'المجموعة',
              value: 'اختر مجموعة فرعية',
              onTap: () => _pickDeck(decks),
            ),
          ],
          const SizedBox(height: 18),
          _KindSelector(
            selected: _kind,
            onChanged: (value) => setState(() {
              _kind = value;
              _error = null;
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _kindHint(_kind),
            style: context.texts.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 18),
          if (_kind == _CardKind.occlusion)
            _occlusionSection(context)
          else
            ..._textSections(context),
          const SizedBox(height: 22),
          _previewSection(context),
          const SizedBox(height: 22),
          _tagsSection(context),
          const SizedBox(height: 14),
          _advancedSection(context),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            _ErrorNote(message: _error!),
          ],
        ],
      ),
      bottomNavigationBar: _BottomBar(
        saving: _saving,
        editing: _editing,
        onSave: _saveAndClose,
        onSaveAnother: _saveAndContinue,
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    return IconButton(
      onPressed: () => context.pop(),
      icon: const Icon(CupertinoIcons.xmark),
      tooltip: 'إغلاق',
    );
  }

  String _kindHint(_CardKind kind) {
    switch (kind) {
      case _CardKind.basic:
        return 'سؤال في الوجه وجواب في الخلف. مناسب للمفاهيم والتعريفات.';
      case _CardKind.cloze:
        return 'اكتب النص، حدّد الكلمة المهمة، ثم اضغط «فراغ» لتصبح '
            '{{c1::الكلمة}} وتُخفى أثناء المراجعة.';
      case _CardKind.occlusion:
        return 'ارفع صورة وارسم مستطيلات فوق الأجزاء التي تريد اختبارها.';
    }
  }

  Future<void> _pickDeck(List<DeckNode> decks) async {
    final String? value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheet) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'اختر المجموعة',
                    style: context.texts.titleMedium,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final DeckNode deck in decks)
                      ListTile(
                        leading: Icon(deck.icon, color: deck.color),
                        title: Text(deck.title),
                        subtitle: deck.parentId == null
                            ? const Text('مجموعة رئيسية')
                            : null,
                        onTap: () => Navigator.of(sheet).pop(deck.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _deckId = value;
        _error = null;
      });
    }
  }

  List<Widget> _textSections(BuildContext context) {
    final bool cloze = _kind == _CardKind.cloze;
    return <Widget>[
      _FieldCard(
        label: cloze ? 'النص مع الفراغ' : 'وجه البطاقة',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Toolbar(
              onBold: () => _toggleWrap('**', '**', 'نص عريض'),
              onItalic: () => _toggleWrap('_', '_', 'نص مائل'),
              onMath: () => _toggleWrap(r'$', r'$', 'x^2'),
              onCloze: cloze
                  ? () => _toggleWrap('{{c1::', '}}', 'الإجابة')
                  : null,
              onImage: _uploading ? null : () => _attach(image: true),
              onAudio: _uploading ? null : () => _attach(image: false),
              uploading: _uploading,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _front,
              focusNode: _frontFocus,
              autofocus: !_editing,
              minLines: 4,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              style: context.texts.bodyLarge?.copyWith(height: 1.75),
              decoration: editorDecoration(
                context,
                hint: cloze
                    ? 'مثال: عاصمة فرنسا هي {{c1::باريس}}.'
                    : 'اكتب السؤال أو المفهوم…',
                multiline: true,
              ),
            ),
            if (cloze) ...<Widget>[
              const SizedBox(height: 10),
              _ClozeHelper(
                count: clozeCount(_front.text),
                onInsert: () => _toggleWrap('{{c1::', '}}', 'الإجابة'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _FieldCard(
        label: cloze ? 'شرح إضافي (اختياري)' : 'الإجابة',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Toolbar(
              onBold: () => _toggleWrap('**', '**', 'نص عريض'),
              onItalic: () => _toggleWrap('_', '_', 'نص مائل'),
              onMath: () => _toggleWrap(r'$', r'$', 'x^2'),
              onCloze: null,
              onImage: _uploading ? null : () => _attach(image: true),
              onAudio: _uploading ? null : () => _attach(image: false),
              uploading: _uploading,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _back,
              focusNode: _backFocus,
              minLines: 3,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              style: context.texts.bodyLarge?.copyWith(height: 1.75),
              decoration: editorDecoration(
                context,
                hint: cloze ? 'سياق أو تفصيل يظهر بعد الكشف…' : 'اكتب الإجابة…',
                multiline: true,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _occlusionSection(BuildContext context) {
    return _FieldCard(
      label: 'صورة التغطية',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_imageUrl == null)
            InkWell(
              onTap: _uploading ? null : () => _attach(image: true),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.raisedSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: context.hairline,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      CupertinoIcons.photo_on_rectangle,
                      size: 30,
                      color: context.brandInk,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _uploading ? 'جارٍ الرفع…' : 'اختر صورة من الجهاز',
                      style: context.texts.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PNG أو JPG',
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            OcclusionCanvas(
              imageUrl: _imageUrl!,
              boxes: _boxes,
              onChanged: (List<OcclusionBox> value) =>
                  setState(() => _boxes = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _uploading ? null : () => _attach(image: true),
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                  label: const Text('تغيير الصورة'),
                ),
                const Spacer(),
                if (_boxes.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _boxes = <OcclusionBox>[]),
                    icon: const Icon(CupertinoIcons.trash, size: 16),
                    label: const Text('مسح التغطيات'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text('الإجابة أو التعليق', style: context.texts.labelLarge),
          const SizedBox(height: 7),
          TextField(
            controller: _back,
            focusNode: _backFocus,
            minLines: 2,
            maxLines: 5,
            style: context.texts.bodyLarge?.copyWith(height: 1.7),
            decoration: editorDecoration(
              context,
              hint: 'ما الذي يجب أن يتذكره المتعلّم؟',
              multiline: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewSection(BuildContext context) {
    final String previewFront = _kind == _CardKind.occlusion
        ? (_imageUrl == null ? '' : '')
        : _front.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.eye_fill,
                size: 14,
                color: context.brandInk,
              ),
              const SizedBox(width: 6),
              Text(
                'معاينة مباشرة',
                style: context.texts.labelSmall?.copyWith(
                  color: context.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'كما ستظهر في المراجعة',
                style: context.texts.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_kind == _CardKind.occlusion && _imageUrl != null)
                  OcclusionView(
                    imageUrl: _imageUrl!,
                    boxes: _boxes,
                    height: 170,
                  )
                else if (previewFront.trim().isEmpty)
                  Text(
                    'سيظهر وجه البطاقة هنا',
                    style: context.texts.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  CardMarkup(
                    text: previewFront,
                    style: context.texts.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                    revealCloze: _kind == _CardKind.cloze,
                    mediaHeight: 130,
                  ),
                if (_back.text.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Divider(color: context.hairline),
                  const SizedBox(height: 10),
                  CardMarkup(
                    text: _back.text,
                    style: context.texts.bodyMedium!.copyWith(height: 1.7),
                    mediaHeight: 110,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 220));
  }

  Widget _tagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('الوسوم', style: context.texts.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.raisedSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.tag,
                size: 16,
                color: context.texts.bodySmall?.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tagInput,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addTag,
                  decoration: const InputDecoration(
                    hintText: 'اكتب وسماً ثم اضغط إدخال',
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _addTag(_tagInput.text),
                icon: const Icon(CupertinoIcons.add, size: 18),
                tooltip: 'إضافة وسم',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        if (_tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final String tag in _tags)
                InputChip(
                  label: Text(tag),
                  labelStyle: context.texts.labelSmall?.copyWith(
                    color: context.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: context.softAccent,
                  side: BorderSide.none,
                  deleteIconColor: context.brandInk,
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _advancedSection(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 6),
        iconColor: context.brandInk,
        collapsedIconColor: context.texts.bodySmall?.color,
        title: Text('تلميح وملاحظة', style: context.texts.labelLarge),
        children: <Widget>[
          TextField(
            controller: _hint,
            decoration: editorDecoration(
              context,
              hint: 'تلميح يظهر عند الحاجة',
            ),
          ),
          const SizedBox(height: 10),
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
    );
  }
}

// ------------------------------------------------------------------ widgets --

class _DeckBanner extends StatelessWidget {
  const _DeckBanner({required this.deck, this.onChange});

  final DeckNode deck;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: deck.color.withValues(alpha: context.isDark ? 0.28 : 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(deck.icon, size: 18, color: deck.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'في: ${deck.title}',
              style: context.texts.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onChange != null)
            TextButton(onPressed: onChange, child: const Text('تغيير')),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.raisedSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Text(label, style: context.texts.bodySmall),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: context.texts.titleSmall,
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_back,
              size: 16,
              color: context.texts.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.selected, required this.onChanged});

  final _CardKind selected;
  final ValueChanged<_CardKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<_KindSpec> specs = <_KindSpec>[
      _KindSpec(
        kind: _CardKind.basic,
        label: 'أساسية',
        icon: CupertinoIcons.rectangle_stack_fill,
      ),
      _KindSpec(
        kind: _CardKind.cloze,
        label: 'ملء فراغ',
        icon: CupertinoIcons.textformat_abc,
      ),
      _KindSpec(
        kind: _CardKind.occlusion,
        label: 'تغطية صورة',
        icon: CupertinoIcons.rectangle_on_rectangle,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          for (final _KindSpec spec in specs)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(spec.kind),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == spec.kind
                        ? context.cardSurface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected == spec.kind
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        spec.icon,
                        size: 17,
                        color: selected == spec.kind
                            ? context.brandInk
                            : context.texts.bodySmall?.color,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.label,
                        style: context.texts.labelSmall?.copyWith(
                          fontWeight: selected == spec.kind
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected == spec.kind
                              ? context.brandInk
                              : context.texts.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KindSpec {
  const _KindSpec({
    required this.kind,
    required this.label,
    required this.icon,
  });

  final _CardKind kind;
  final String label;
  final IconData icon;
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: context.texts.labelLarge?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onBold,
    required this.onItalic,
    required this.onMath,
    required this.onImage,
    required this.onAudio,
    required this.uploading,
    this.onCloze,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onMath;
  final VoidCallback? onCloze;
  final VoidCallback? onImage;
  final VoidCallback? onAudio;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(14),
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
          if (onCloze != null)
            _ToolButton(
              icon: Icons.data_object,
              tooltip: 'فراغ',
              onTap: onCloze!,
            ),
          const Spacer(),
          if (uploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 17,
            color: onTap == null
                ? context.texts.bodySmall?.color?.withValues(alpha: 0.4)
                : context.ink,
          ),
        ),
      ),
    );
  }
}

class _ClozeHelper extends StatelessWidget {
  const _ClozeHelper({required this.count, required this.onInsert});

  final int count;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.softAccent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.info_circle,
                size: 15,
                color: context.brandInk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'الصيغة: {{c1::الإجابة}} — الرقم c1 يجمع الفراغات المتشابهة.',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.brandInk,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                count == 0
                    ? 'لا يوجد فراغ بعد'
                    : 'عدد الفراغات: $count',
                style: context.texts.labelSmall?.copyWith(
                  color: context.brandInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onInsert,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(CupertinoIcons.add, size: 14),
                label: const Text('إضافة فراغ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.dangerInk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 17,
            color: context.dangerInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodySmall?.copyWith(
                color: context.dangerInk,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.saving,
    required this.editing,
    required this.onSave,
    required this.onSaveAnother,
  });

  final bool saving;
  final bool editing;
  final VoidCallback onSave;
  final VoidCallback onSaveAnother;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.cardSurface,
        border: Border(top: BorderSide(color: context.hairline)),
      ),
      child: Row(
        children: <Widget>[
          if (!editing) ...<Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onSaveAnother,
                child: const Text('حفظ وإضافة أخرى'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton(
              onPressed: saving ? null : onSave,
              child: Text(
                saving
                    ? 'جارٍ الحفظ…'
                    : editing
                    ? 'حفظ التعديلات'
                    : 'حفظ البطاقة',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
