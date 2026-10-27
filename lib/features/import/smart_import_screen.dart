import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/card_import_parser.dart';
import '../../data/content_providers.dart';
import '../../domain/card_draft.dart';
import '../../domain/models.dart';

/// Paste a list, check it, then save the whole batch at once.
///
/// The screen has two states. In the first the user pastes text and the
/// parser turns it into drafts; in the second the drafts are shown as cards
/// that can be opened in the full editor. Nothing is written to the database
/// until the user presses save.
class SmartImportScreen extends ConsumerStatefulWidget {
  const SmartImportScreen({required this.deckId, super.key});

  final String deckId;

  @override
  ConsumerState<SmartImportScreen> createState() => _SmartImportScreenState();
}

class _SmartImportScreenState extends ConsumerState<SmartImportScreen> {
  final TextEditingController _input = TextEditingController();

  /// Parsing on every keystroke is wasteful on a two-thousand-line paste, so
  /// the live count trails the caret by a frame or two instead of blocking it.
  static const Duration _parseDelay = Duration(milliseconds: 130);

  Timer? _timer;
  CardImportResult _live = const CardImportResult(
    drafts: <CardDraft>[],
    skipped: 0,
  );

  List<CardDraft> _drafts = <CardDraft>[];
  int _skipped = 0;
  bool _previewing = false;
  bool _saving = false;

  /// Which way the two panes move. Forward when entering the preview, back
  /// when returning to the text, so the screen reads as a stack.
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.removeListener(_onTextChanged);
    _input.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _timer?.cancel();
    _timer = Timer(_parseDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _live = parseCardImport(_input.text));
    });
  }

  void _preview() {
    final CardImportResult result = parseCardImport(_input.text);
    if (result.isEmpty) {
      showAppMessage(
        context,
        'لم نجد أي بطاقة. تأكد من وجود الرمز | بين السؤال والجواب.',
        kind: AppMessageKind.error,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _live = result;
      _drafts = result.drafts;
      _skipped = result.skipped;
      _previewing = true;
      _forward = true;
    });
  }

  void _backToText() {
    HapticFeedback.selectionClick();
    setState(() {
      _previewing = false;
      _forward = false;
    });
  }

  /// Pulls the clipboard into the field, appended after whatever is there.
  ///
  /// The whole point of this screen is moving text from somewhere else, and
  /// long-press-and-paste on a large text area is fiddly on a phone.
  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }
    final String text = data?.text ?? '';
    if (text.trim().isEmpty) {
      showAppMessage(context, 'الحافظة فارغة.', kind: AppMessageKind.error);
      return;
    }
    final String current = _input.text;
    final String joined = current.trim().isEmpty ? text : '$current\n$text';
    _input.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length),
    );
    HapticFeedback.selectionClick();
  }

  void _clear() {
    _input.clear();
    setState(
      () => _live = const CardImportResult(drafts: <CardDraft>[], skipped: 0),
    );
  }

  /// Opens the real editor on one draft and swaps in whatever comes back.
  Future<void> _editDraft(int index) async {
    final CardDraft? edited = await context.push<CardDraft>(
      '/draft-card?deckId=${widget.deckId}',
      extra: _drafts[index],
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() => _drafts[index] = edited);
  }

  void _removeDraft(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _drafts = List<CardDraft>.of(_drafts)..removeAt(index);
      if (_drafts.isEmpty) {
        // Nothing left to preview, so fall back to the paste view instead of
        // showing an empty list.
        _previewing = false;
        _forward = false;
      }
    });
  }

  Future<void> _saveAll() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final List<String> ids = await ref
          .read(contentRepositoryProvider)
          .addCards(deckId: widget.deckId, drafts: _drafts);
      if (!mounted) {
        return;
      }
      if (ids.isEmpty) {
        setState(() => _saving = false);
        showAppMessage(
          context,
          'لا توجد بطاقات صالحة للحفظ.',
          kind: AppMessageKind.error,
        );
        return;
      }
      context.pop('تمت إضافة ${ids.length} بطاقة.');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showAppMessage(
          context,
          'تعذّر حفظ البطاقات. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => const _HelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DeckNode? deck = ref.watch(deckByIdProvider(widget.deckId));
    final int ready = _previewing ? _drafts.length : _live.drafts.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(CupertinoIcons.xmark),
          tooltip: 'إغلاق',
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _previewing ? 'مراجعة البطاقات' : 'الاستيراد الذكي',
            key: ValueKey<bool>(_previewing),
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _showHelp,
            icon: const Icon(CupertinoIcons.question_circle),
            tooltip: 'مساعدة',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool incoming = child.key == ValueKey<bool>(_previewing);
          final double travel = incoming
              ? (_forward ? 0.055 : -0.055)
              : (_forward ? -0.03 : 0.03);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, travel),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _previewing
            ? _previewBody(context)
            : _composeBody(context, deck),
      ),
      bottomNavigationBar: _bottomBar(context, ready),
    );
  }

  Widget _composeBody(BuildContext context, DeckNode? deck) {
    return ListView(
      key: const ValueKey<bool>(false),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: <Widget>[
        _FormatCard(deckTitle: deck?.title),
        const SizedBox(height: 14),
        _EditorBox(
          controller: _input,
          onPaste: _paste,
          onClear: _input.text.isEmpty ? null : _clear,
        ),
        const SizedBox(height: 10),
        _LiveStatus(ready: _live.drafts.length, skipped: _live.skipped),
      ],
    );
  }

  Widget _previewBody(BuildContext context) {
    return ListView.builder(
      key: const ValueKey<bool>(true),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      itemCount: _drafts.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PreviewHeader(count: _drafts.length, skipped: _skipped),
          );
        }
        final int position = index - 1;
        return _Appear(
          index: position,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DraftTile(
              index: index,
              draft: _drafts[position],
              onTap: () => _editDraft(position),
              onRemove: () => _removeDraft(position),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context, int ready) {
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
          if (_previewing) ...<Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _backToText,
                child: const Text('تعديل النص'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: _previewing ? 2 : 1,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : _previewing
                  ? _saveAll
                  : (ready == 0 ? null : _preview),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_saving) ...<Widget>[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _saving
                          ? 'جارٍ الحفظ…'
                          : _previewing
                          ? 'حفظ الكل (${_drafts.length})'
                          : 'معاينة',
                      key: ValueKey<String>(
                        '$_saving-${_previewing ? _drafts.length : 0}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The text field with the chrome around it: a header with paste and clear,
/// then the writing surface itself.
class _EditorBox extends StatelessWidget {
  const _EditorBox({
    required this.controller,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: <Widget>[
                Icon(
                  CupertinoIcons.doc_text,
                  size: 14,
                  color: context.texts.bodySmall?.color,
                ),
                const SizedBox(width: 6),
                Text('النص', style: context.texts.labelMedium),
                const Spacer(),
                _BoxAction(
                  icon: CupertinoIcons.doc_on_clipboard,
                  label: 'لصق',
                  onTap: onPaste,
                ),
                const SizedBox(width: 4),
                _BoxAction(
                  icon: CupertinoIcons.xmark_circle,
                  label: 'مسح',
                  onTap: onClear,
                ),
              ],
            ),
          ),
          Divider(height: 0.7, thickness: 0.7, color: context.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: controller,
              minLines: 12,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 14,
                height: 1.95,
              ),
              decoration: const InputDecoration(
                hintText:
                    'الصق هنا…\n\n'
                    'ما عاصمة اليابان؟ | طوكيو | تقع على المحيط الهادئ',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small text-and-icon button used in the editor header.
class _BoxAction extends StatelessWidget {
  const _BoxAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.texts.bodySmall?.color ?? AppColors.muted;
    final Color color = onTap == null
        ? muted.withValues(alpha: 0.4)
        : context.brandInk;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The running count under the field. It swaps in place so the line never
/// jumps as digits change.
class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.ready, required this.skipped});

  final int ready;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    final bool empty = ready == 0;
    final Color tint = empty ? context.muted : context.brandInk;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Row(
        key: ValueKey<String>('$ready-$skipped'),
        children: <Widget>[
          Icon(
            empty
                ? CupertinoIcons.doc_text
                : CupertinoIcons.checkmark_circle_fill,
            size: 14,
            color: tint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              empty
                  ? 'لا توجد بطاقات بعد.'
                  : '$ready بطاقة جاهزة'
                        '${skipped > 0 ? ' · $skipped سطر متجاهل' : ''}',
              style: context.texts.bodySmall?.copyWith(
                color: empty ? null : tint,
                fontWeight: empty ? null : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in, a beat after the one before it.
///
/// The delay is capped so a hundred-card paste still finishes arriving in
/// under half a second instead of trickling in for three.
class _Appear extends StatelessWidget {
  const _Appear({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int step = index > 8 ? 8 : index;
    final int total = 260 + step * 34;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(step * 34 / total, 1, curve: Curves.easeOutCubic),
      builder: (BuildContext context, double value, Widget? built) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: built,
          ),
        );
      },
      child: child,
    );
  }
}

/// Explains the accepted shape with three concrete examples.
class _FormatCard extends StatelessWidget {
  const _FormatCard({this.deckTitle});

  final String? deckTitle;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.sparkles,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('سطر واحد لكل بطاقة', style: context.texts.titleSmall),
                    if (deckTitle != null)
                      Text(
                        'إلى مجموعة: $deckTitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _FormatRow(sample: 'السؤال | الجواب'),
          const _FormatRow(sample: 'السؤال | الجواب | تلميح'),
          const _FormatRow(sample: 'السؤال | الجواب | تلميح | ملاحظة'),
          const SizedBox(height: 6),
          Text(
            'الحقول مفصولة بالرمز | . التلميح والملاحظة اختياريان، '
            'وأي سطر بلا | يُتجاهل.',
            style: context.texts.bodySmall?.copyWith(height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.sample});

  final String sample;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.isDark ? AppColors.darkSurfaceHigh : AppColors.canvas,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          sample,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 12.5,
            color: context.texts.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.count, required this.skipped});

  final int count;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$count بطاقة جاهزة للإضافة', style: context.texts.titleMedium),
        const SizedBox(height: 3),
        Text(
          'اضغط أي بطاقة لتعديلها في المحرّر الكامل قبل الحفظ.',
          style: context.texts.bodySmall?.copyWith(height: 1.7),
        ),
        if (skipped > 0) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 14,
                  color: AppColors.warningInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تجاهل $skipped سطراً: لا يحتوي على | أو ينقصه أحد الطرفين.',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 11.5,
                      height: 1.7,
                      color: AppColors.warningInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.index,
    required this.draft,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final CardDraft draft;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.texts.bodySmall?.color ?? AppColors.muted;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2, left: 8),
            decoration: BoxDecoration(
              color: context.isDark
                  ? AppColors.darkSurfaceHigh
                  : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: TextStyle(
                fontFamily: 'ReadexPro',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.isDark
                    ? AppColors.darkAccent
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  draft.front,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  draft.back,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12.5,
                    height: 1.7,
                    color: muted,
                  ),
                ),
                if (draft.hint.isNotEmpty ||
                    draft.note.isNotEmpty ||
                    draft.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (draft.hint.isNotEmpty)
                          const _MiniChip(
                            icon: CupertinoIcons.lightbulb,
                            label: 'تلميح',
                          ),
                        if (draft.note.isNotEmpty)
                          const _MiniChip(
                            icon: CupertinoIcons.doc_text,
                            label: 'ملاحظة',
                          ),
                        for (final String tag in draft.tags.take(3))
                          _MiniChip(icon: CupertinoIcons.tag, label: tag),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(CupertinoIcons.xmark, size: 15),
            color: muted,
            tooltip: 'حذف المسودة',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.texts.bodySmall?.color ?? AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurfaceHigh : AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 10, color: muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 10.5,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hands the user a prompt they can paste into an AI assistant.
///
/// The text is selectable and copyable because most people will paste it into
/// a chat app rather than read it here.
class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kSmartImportPrompt));
    if (!context.mounted) {
      return;
    }
    showAppMessage(context, 'تم نسخ الطلب. ألصقه في مساعدك المفضّل.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('جهّز نصك بمساعدة الذكاء الاصطناعي'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'انسخ الطلب التالي، ألصقه في مساعدك، ثم أضف نصك في آخره. '
              'ستحصل على سطور جاهزة للصق هنا.',
              style: context.texts.bodySmall?.copyWith(height: 1.8),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDark
                    ? AppColors.darkSurfaceHigh
                    : AppColors.canvas,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  kSmartImportPrompt,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 11.5,
                    height: 1.85,
                    color: context.texts.bodySmall?.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
        FilledButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(CupertinoIcons.doc_on_doc, size: 15),
          label: const Text('نسخ الطلب'),
        ),
      ],
    );
  }
}
