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

  List<CardDraft> _drafts = <CardDraft>[];
  int _skipped = 0;
  bool _previewing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _input.removeListener(_onTextChanged);
    _input.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Live count shown under the field, so the user sees the shape of the
  /// paste before committing to a preview.
  CardImportResult get _live => parseCardImport(_input.text);

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
    setState(() {
      _drafts = result.drafts;
      _skipped = result.skipped;
      _previewing = true;
    });
  }

  void _backToText() {
    setState(() => _previewing = false);
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
    setState(() {
      _drafts = List<CardDraft>.of(_drafts)..removeAt(index);
      if (_drafts.isEmpty) {
        // Nothing left to preview, so fall back to the paste view instead of
        // showing an empty list.
        _previewing = false;
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
        title: Text(_previewing ? 'مراجعة البطاقات' : 'الاستيراد الذكي'),
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
        duration: const Duration(milliseconds: 220),
        child: _previewing
            ? _previewBody(context)
            : _composeBody(context, deck),
      ),
      bottomNavigationBar: _bottomBar(context, ready),
    );
  }

  Widget _composeBody(BuildContext context, DeckNode? deck) {
    final CardImportResult live = _live;
    return ListView(
      key: const ValueKey<String>('compose'),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: <Widget>[
        _FormatCard(deckTitle: deck?.title),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: _input,
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
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Icon(
              live.isEmpty
                  ? CupertinoIcons.doc_text
                  : CupertinoIcons.checkmark_circle_fill,
              size: 14,
              color: live.isEmpty
                  ? context.texts.bodySmall?.color
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                live.isEmpty
                    ? 'لا توجد بطاقات بعد.'
                    : '${live.drafts.length} بطاقة جاهزة'
                          '${live.skipped > 0 ? ' · ${live.skipped} سطر متجاهل' : ''}',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewBody(BuildContext context) {
    return ListView.builder(
      key: const ValueKey<String>('preview'),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      itemCount: _drafts.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PreviewHeader(
              count: _drafts.length,
              skipped: _skipped,
            ),
          );
        }
        final int position = index - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DraftTile(
            index: index,
            draft: _drafts[position],
            onTap: () => _editDraft(position),
            onRemove: () => _removeDraft(position),
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
              child: Text(
                _saving
                    ? 'جارٍ الحفظ…'
                    : _previewing
                    ? 'حفظ الكل (${_drafts.length})'
                    : 'معاينة',
              ),
            ),
          ),
        ],
      ),
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
                    Text(
                      'سطر واحد لكل بطاقة',
                      style: context.texts.titleSmall,
                    ),
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
          color: context.isDark
              ? AppColors.darkSurfaceHigh
              : AppColors.canvas,
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
        Text(
          '$count بطاقة جاهزة للإضافة',
          style: context.texts.titleMedium,
        ),
        const SizedBox(height: 3),
        Text(
          'اضغط أي بطاقة لتعديلها في المحرّر الكامل قبل الحفظ.',
          style: context.texts.bodySmall?.copyWith(height: 1.7),
        ),
        if (skipped > 0) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
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
