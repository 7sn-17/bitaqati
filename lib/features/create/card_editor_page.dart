import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_markup.dart';
import '../../core/widgets/speak_button.dart';
import '../../data/content_providers.dart';
import '../../data/media_upload.dart';
import '../../domain/card_draft.dart';
import '../../domain/models.dart';
import 'editor_common.dart';
import 'occlusion_editor.dart';

/// Full-screen card editor used for both "new card" and "edit card".
///
/// Replaces the old bottom sheet: the sheet could not hold a media toolbar,
/// a live preview and an occlusion canvas at the same time.
class CardEditorPage extends ConsumerStatefulWidget {
  const CardEditorPage({
    this.deckId,
    this.cardId,
    this.initial,
    this.collectOnly = false,
    super.key,
  });

  final String? deckId;
  final String? cardId;

  /// Pre-filled content for a brand-new card. Used by the smart import
  /// preview, where the card already exists as a draft.
  final CardDraft? initial;

  /// When true the editor returns the edited [CardDraft] instead of writing to
  /// the database, so the caller keeps owning the card until it saves.
  final bool collectOnly;

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
  int _hydrateAttempts = 0;
  _CardKind _kind = _CardKind.basic;
  List<String> _tags = <String>[];
  String? _imageUrl;
  List<OcclusionBox> _boxes = <OcclusionBox>[];

  /// Attachments, kept beside the text rather than inside it.
  ///
  /// The stored format is still inline markup — the review screen, the card
  /// list and the public library all render it — but the editor never shows a
  /// URL: a picture is a thumbnail and a recording is a chip, and the markup is
  /// assembled only on save.
  final List<_Attachment> _frontMedia = <_Attachment>[];
  final List<_Attachment> _backMedia = <_Attachment>[];

  /// Which field the toolbar formats.
  ///
  /// Tapping a toolbar button moves focus off the text field, so asking "which
  /// field has focus" at that moment answers "neither" — and the old code then
  /// formatted the front field while the user was writing the back one. The
  /// last field the writer actually touched is remembered instead.
  bool _frontActive = true;

  /// The last real selection in each field.
  ///
  /// Tapping a toolbar button can collapse the caret before the button's
  /// callback runs. Remembering the highlighted range is what makes «عريض» act
  /// on the word the writer selected instead of on an empty cursor.
  TextSelection? _frontSelection;
  TextSelection? _backSelection;

  /// One controller per box, kept in step with [_boxes] so the answer fields
  /// survive a rebuild when a box is added, moved or deleted.
  final List<TextEditingController> _boxControllers = <TextEditingController>[];

  bool get _editing => widget.cardId != null;

  @override
  void initState() {
    super.initState();
    _deckId = widget.deckId;
    _frontFocus.addListener(_onFocusChange);
    _backFocus.addListener(_onFocusChange);
    _front.addListener(_refresh);
    _back.addListener(_refresh);
    final CardDraft? initial = widget.initial;
    if (initial != null) {
      // The draft is already in memory, so there is nothing to load.
      _hydrated = true;
      _applyDraft(initial);
    } else if (_editing) {
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
    for (final TextEditingController controller in _boxControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    final TextSelection front = _front.selection;
    if (front.isValid && !front.isCollapsed) {
      _frontSelection = front;
    }
    final TextSelection back = _back.selection;
    if (back.isValid && !back.isCollapsed) {
      _backSelection = back;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChange() {
    if (_frontFocus.hasFocus) {
      _frontActive = true;
    } else if (_backFocus.hasFocus) {
      _frontActive = false;
    }
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
      // The cards stream may still be loading on a cold deep link. Retry for a
      // few frames, then stop instead of rebuilding forever.
      _hydrateAttempts++;
      if (_hydrateAttempts > 30) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted && !_hydrated) {
          _hydrate(notify: false);
        }
      });
      return;
    }
    _hydrated = true;
    _deckId = found.deckId;
    _frontMedia.clear();
    _backMedia.clear();
    if (found.type == 'occlusion') {
      // An occlusion front *is* its image, so it stays in _imageUrl.
      _front.text = '';
      _back.text = found.back;
    } else {
      _front.text = _splitMedia(found.front, _frontMedia);
      _back.text = _splitMedia(found.back, _backMedia);
    }
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
        _syncBoxControllers();
      default:
        _kind = _CardKind.basic;
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  /// Copies a draft into the controllers. Mirrors [_hydrate], but the content
  /// comes from memory instead of the database.
  void _applyDraft(CardDraft draft) {
    _frontMedia.clear();
    _backMedia.clear();
    if (draft.type == 'occlusion') {
      _front.text = '';
      _back.text = draft.back;
    } else {
      _front.text = _splitMedia(draft.front, _frontMedia);
      _back.text = _splitMedia(draft.back, _backMedia);
    }
    _hint.text = draft.hint;
    _note.text = draft.note;
    _tags = List<String>.of(draft.tags);
    switch (draft.type) {
      case 'cloze':
        _kind = _CardKind.cloze;
      case 'occlusion':
        _kind = _CardKind.occlusion;
        final RegExpMatch? image = kImageRegex.firstMatch(draft.front);
        _imageUrl = image?.group(2);
        _boxes = occlusionBoxes(draft.occlusion);
        _syncBoxControllers();
      default:
        _kind = _CardKind.basic;
    }
  }

  /// Snapshots the editor into a draft without touching the database.
  CardDraft _collectDraft() {
    return CardDraft(
      front: _resolvedFront(),
      back: _resolvedBack(),
      hint: _hint.text.trim(),
      note: _note.text.trim(),
      tags: List<String>.of(_tags),
      type: _typeName,
      occlusion: _kind == _CardKind.occlusion ? occlusionPayload(_boxes) : null,
    );
  }

  MarkupTextController get _activeField => _frontActive ? _front : _back;

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

  /// Turns the selection into a cloze deletion, and makes the card a cloze
  /// card if it was not one already.
  ///
  /// This is the whole flow the writer sees: select a word, tap «فراغ», and the
  /// word becomes a blank. The `{{c1::…}}` form is an implementation detail
  /// that stays visible only as a highlighted box in the field.
  void _makeCloze() {
    if (_kind == _CardKind.occlusion) {
      return;
    }
    setState(() {
      _kind = _CardKind.cloze;
      _frontActive = true;
    });
    _toggleWrap('{{c1::', '}}', 'الإجابة', controller: _front);
    _frontFocus.requestFocus();
  }

  /// Wraps or unwraps the selection with [open]/[close].
  void _toggleWrap(
    String open,
    String close,
    String placeholder, {
    MarkupTextController? controller,
  }) {
    final MarkupTextController target = controller ?? _activeField;
    final TextEditingValue value = target.value;
    final String text = value.text;
    final TextSelection selection = value.selection;
    final TextSelection? remembered = target == _front
        ? _frontSelection
        : _backSelection;
    final bool reuse =
        (!selection.isValid || selection.isCollapsed) &&
        remembered != null &&
        remembered.end <= text.length;
    final int start = reuse
        ? remembered.start
        : (selection.isValid ? selection.start : text.length);
    final int end = reuse
        ? remembered.end
        : (selection.isValid ? selection.end : text.length);
    final String selected = text.substring(start, end);
    final String before = text.substring(0, start);
    final String after = text.substring(end);

    if (before.endsWith(open) && after.startsWith(close)) {
      final String next =
          before.substring(0, before.length - open.length) +
          selected +
          after.substring(close.length);
      target.value = TextEditingValue(
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
      target.value = TextEditingValue(
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
    target.value = TextEditingValue(
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
      // The picker runs in another activity; the editor may have been popped
      // while it was open, and every branch below calls setState.
      if (!mounted) {
        return;
      }
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
      setState(() {
        (_frontActive ? _frontMedia : _backMedia).add(
          _Attachment(
            markup: media.markup,
            url: media.url,
            image: media.isImage,
            name: media.name,
          ),
        );
        _error = media.uploaded
            ? null
            : 'تم إرفاق الملف محلياً. سيُرفع إلى السحابة عند توفر الاتصال.';
      });
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

  /// Keeps the answer fields in step with the boxes on the canvas.
  void _syncBoxControllers() {
    while (_boxControllers.length > _boxes.length) {
      _boxControllers.removeLast().dispose();
    }
    while (_boxControllers.length < _boxes.length) {
      _boxControllers.add(TextEditingController());
    }
    for (int index = 0; index < _boxes.length; index++) {
      final String answer = _boxes[index].answer;
      if (_boxControllers[index].text != answer) {
        _boxControllers[index].text = answer;
      }
    }
  }

  /// Detaches one attachment. The markup only exists on save, so there is no
  /// token to hunt for in the text any more.
  void _removeMedia(_Attachment item) {
    setState(() {
      _frontMedia.remove(item);
      _backMedia.remove(item);
    });
  }

  /// Pulls every `![..](..)` and `[صوت](..)` token out of [text].
  ///
  /// Used when a stored card is loaded: the field must show prose, not URLs.
  static String _splitMedia(String text, List<_Attachment> target) {
    String rest = text;
    for (final RegExpMatch match in kImageRegex.allMatches(text)) {
      target.add(
        _Attachment(
          markup: match.group(0)!,
          url: match.group(2) ?? '',
          image: true,
          name: match.group(1) ?? '',
        ),
      );
      rest = rest.replaceFirst(match.group(0)!, '');
    }
    for (final RegExpMatch match in kAudioRegex.allMatches(text)) {
      target.add(
        _Attachment(
          markup: match.group(0)!,
          url: match.group(2) ?? '',
          image: false,
        ),
      );
      rest = rest.replaceFirst(match.group(0)!, '');
    }
    return rest.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Puts the attachments back into the stored markup, after the prose.
  static String _joinMedia(String text, List<_Attachment> media) {
    final String body = text.trim();
    if (media.isEmpty) {
      return body;
    }
    final StringBuffer buffer = StringBuffer(body);
    for (final _Attachment item in media) {
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(item.markup);
    }
    return buffer.toString().trim();
  }

  /// Adds a tag without scrolling to the tag section at the bottom.
  Future<void> _openTagSheet(BuildContext context) async {
    final TextEditingController input = TextEditingController();
    final String? value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheet) => EditorSheetFrame(
        title: 'وسم جديد',
        subtitle: 'الوسوم تُستخدم للتصفية والبحث. افصل بينها بفاصلة.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: input,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (String text) => Navigator.of(sheet).pop(text),
              decoration: editorDecoration(
                context,
                hint: 'مثال: فيزياء، الفصل الأول',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheet).pop(input.text),
                child: const Text('إضافة الوسم'),
              ),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (value != null && value.trim().isNotEmpty) {
      _addTag(value);
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
    return _joinMedia(_front.text, _frontMedia);
  }

  String _resolvedBack() {
    final String back = _joinMedia(_back.text, _backMedia);
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
    if (widget.collectOnly) {
      // Nothing is persisted here: the caller owns the draft until it decides
      // to save the whole batch.
      setState(() => _saving = false);
      return true;
    }
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
    if (widget.collectOnly) {
      context.pop(_collectDraft());
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
      _frontMedia.clear();
      _backMedia.clear();
      _hint.clear();
      _note.clear();
      _tagInput.clear();
      _tags = <String>[];
      _imageUrl = null;
      _boxes = <OcclusionBox>[];
      _error = null;
      _frontActive = true;
    });
    _frontFocus.requestFocus();
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final List<DeckNode> decks = ref.watch(allDecksProvider);

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
                'لا توجد مجموعة بعد',
                style: context.texts.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'أنشئ مجموعة أولاً من الشاشة الرئيسية، '
                'ثم عد هنا لتضيف بطاقاتك.',
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
        title: Text(
          widget.collectOnly
              ? 'تعديل المسودة'
              : _editing
              ? 'تعديل البطاقة'
              : 'بطاقة جديدة',
        ),
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
              value: 'اختر مجموعة',
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
        collectOnly: widget.collectOnly,
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
                        leading: Icon(
                          deck.icon,
                          color: deckInk(deck.color, dark: context.isDark),
                        ),
                        title: Text(deck.title),
                        subtitle: Text('${deck.cardCount} بطاقة'),
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
        trailing: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _front,
          builder: (BuildContext context, TextEditingValue value, Widget? _) =>
              SpeakButton(text: value.text, size: 32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Toolbar(
              onBold: () => _toggleWrap('**', '**', 'نص عريض'),
              onItalic: () => _toggleWrap('_', '_', 'نص مائل'),
              onMath: () => _toggleWrap(r'$', r'$', 'x^2'),
              onCloze: _kind == _CardKind.occlusion ? null : _makeCloze,
              onTags: () => _openTagSheet(context),
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
                    ? 'اكتب النص، ثم حدّد الكلمة التي تريد حجبها واضغط «فراغ».'
                    : 'اكتب السؤال أو المفهوم…',
                multiline: true,
              ),
            ),
            _MediaStrip(items: _frontMedia, onRemove: _removeMedia),
            if (cloze) ...<Widget>[
              const SizedBox(height: 10),
              _ClozeHelper(
                count: clozeCount(_front.text),
                onInsert: _makeCloze,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _FieldCard(
        label: cloze ? 'شرح إضافي (اختياري)' : 'الإجابة',
        trailing: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _back,
          builder: (BuildContext context, TextEditingValue value, Widget? _) =>
              SpeakButton(text: value.text, size: 32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Toolbar(
              onBold: () => _toggleWrap('**', '**', 'نص عريض'),
              onItalic: () => _toggleWrap('_', '_', 'نص مائل'),
              onMath: () => _toggleWrap(r'$', r'$', 'x^2'),
              onCloze: null,
              onTags: () => _openTagSheet(context),
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
            _MediaStrip(items: _backMedia, onRemove: _removeMedia),
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
                  border: Border.all(color: context.hairline, width: 1),
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
                    Text('PNG أو JPG', style: context.texts.bodySmall),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            OcclusionCanvas(
              imageUrl: _imageUrl!,
              boxes: _boxes,
              onChanged: (List<OcclusionBox> value) => setState(() {
                _boxes = value;
                _syncBoxControllers();
              }),
            ),
            if (_boxes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text('إجابة كل تغطية', style: context.texts.labelLarge),
              const SizedBox(height: 6),
              Text(
                'اكتب ما تخفيه كل تغطية. يظهر عند الضغط عليها في المراجعة.',
                style: context.texts.bodySmall,
              ),
              const SizedBox(height: 8),
              for (int index = 0; index < _boxes.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.softAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: context.texts.labelSmall?.copyWith(
                            color: context.brandInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _boxControllers[index],
                          decoration: editorDecoration(
                            context,
                            hint: 'إجابة التغطية ${index + 1}',
                          ),
                          onChanged: (String value) {
                            final List<OcclusionBox> next = <OcclusionBox>[
                              ..._boxes,
                            ];
                            next[index] = next[index].copyWith(answer: value);
                            _boxes = next;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
                    onPressed: () => setState(() {
                      _boxes = <OcclusionBox>[];
                      _syncBoxControllers();
                    }),
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
              Icon(CupertinoIcons.eye_fill, size: 14, color: context.brandInk),
              const SizedBox(width: 6),
              Text(
                'معاينة مباشرة',
                style: context.texts.labelSmall?.copyWith(
                  color: context.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text('كما ستظهر في المراجعة', style: context.texts.labelSmall),
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

/// One attachment, kept beside the text instead of inside it.
@immutable
class _Attachment {
  const _Attachment({
    required this.markup,
    required this.url,
    required this.image,
    this.name = '',
  });

  /// The `![alt](url)` or `[صوت](url)` form written to the database.
  final String markup;

  final String url;
  final bool image;
  final String name;
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.items, required this.onRemove});

  final List<_Attachment> items;
  final ValueChanged<_Attachment> onRemove;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final _Attachment item in items)
            _MediaChip(item: item, onRemove: () => onRemove(item)),
        ],
      ),
    );
  }
}

/// A thumbnail plus a remove button.
///
/// The URL never reaches the field: the writer sees a 46 px preview and an X,
/// and the markup is only assembled when the card is saved.
class _MediaChip extends StatelessWidget {
  const _MediaChip({required this.item, required this.onRemove});

  final _Attachment item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 2, 4),
      decoration: BoxDecoration(
        color: context.raisedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: item.image
                  ? CardImage(url: item.url, height: 46, radius: 0)
                  : ColoredBox(
                      color: context.softAccent,
                      child: Icon(
                        CupertinoIcons.waveform,
                        size: 20,
                        color: context.brandInk,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              item.image
                  ? (item.name.isEmpty ? 'صورة' : item.name)
                  : 'مقطع صوتي',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'إزالة',
          ),
        ],
      ),
    );
  }
}

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
          Icon(
            deck.icon,
            size: 18,
            color: deckInk(deck.color, dark: context.isDark),
          ),
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
  const _FieldCard({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;

  /// Optional control shown at the end of the label row (e.g. a speak button).
  final Widget? trailing;

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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: context.texts.labelLarge?.copyWith(fontSize: 13),
                ),
              ),
              if (trailing != null) trailing!,
            ],
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
    required this.onTags,
    required this.uploading,
    this.onCloze,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onMath;
  final VoidCallback? onCloze;
  final VoidCallback? onImage;
  final VoidCallback? onAudio;
  final VoidCallback onTags;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    // A button that takes focus would steal the selection's field, so the
    // whole row is kept out of the focus tree. Taps still work; focus stays
    // exactly where the writer left it.
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: Container(
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
            _ToolButton(
              icon: Icons.rectangle_outlined,
              tooltip: 'فراغ',
              onTap: onCloze,
            ),
            _ToolButton(
              icon: CupertinoIcons.tag,
              tooltip: 'وسوم',
              onTap: onTags,
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
                  'حدّد كلمة في النص ثم اضغط «فراغ» لتحويلها إلى فراغ. '
                  'تظهر الكلمة المفرغة مظللة داخل النص.',
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
                count == 0 ? 'لا يوجد فراغ بعد' : 'عدد الفراغات: $count',
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
    required this.collectOnly,
    required this.onSave,
    required this.onSaveAnother,
  });

  final bool saving;
  final bool editing;
  final bool collectOnly;
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
          if (!editing && !collectOnly) ...<Widget>[
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
                    : collectOnly
                    ? 'اعتماد التعديل'
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
