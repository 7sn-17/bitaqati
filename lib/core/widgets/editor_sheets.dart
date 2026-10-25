import '../../data/models.dart';
import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../i18n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_surface.dart';
import 'deck_card.dart';

enum CreateAction { deck, subdeck, card, importCards }

enum DeckAction { edit, addSubdeck, addCard, privacy, copy, move, delete }

enum CardAction { edit, toggleSuspend, resetProgress, delete }

class DeckDraft {
  const DeckDraft({
    required this.title,
    required this.description,
    required this.colorHex,
    required this.iconKey,
    required this.tags,
    required this.privacy,
  });

  final String title;
  final String description;
  final String colorHex;
  final String iconKey;
  final List<String> tags;
  final DeckPrivacy privacy;
}

class CardDraft {
  const CardDraft({
    required this.front,
    required this.back,
    required this.hint,
    required this.notes,
    required this.tags,
  });

  final String front;
  final String back;
  final String hint;
  final String notes;
  final List<String> tags;
}

class DeckChoice {
  const DeckChoice(this.id);

  final String? id;
}

Future<CreateAction?> showCreateActions(
  BuildContext context, {
  required bool inDeck,
}) {
  return showModalBottomSheet<CreateAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      final AppStrings strings = context.strings;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.create, style: context.texts.titleLarge),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.create_new_folder_rounded,
              title: strings.createDeck,
              onTap: () => Navigator.pop(context, CreateAction.deck),
            ),
            if (inDeck)
              _ActionTile(
                icon: Icons.subdirectory_arrow_right_rounded,
                title: strings.addSubdeck,
                onTap: () => Navigator.pop(context, CreateAction.subdeck),
              ),
            if (inDeck)
              _ActionTile(
                icon: Icons.note_add_rounded,
                title: strings.addCard,
                onTap: () => Navigator.pop(context, CreateAction.card),
              ),
            if (inDeck)
              _ActionTile(
                icon: Icons.upload_file_rounded,
                title: strings.import,
                onTap: () => Navigator.pop(context, CreateAction.importCards),
              ),
          ],
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: AppIconBadge(icon: icon, size: 38, radius: 12),
      title: Text(title, style: context.texts.bodyLarge),
      trailing: const Icon(Icons.chevron_right_rounded),
      contentPadding: EdgeInsets.zero,
    );
  }
}

Future<DeckAction?> showDeckActions(
  BuildContext context, {
  required DeckSummary deck,
}) {
  return showModalBottomSheet<DeckAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      final AppStrings strings = context.strings;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(deck.title, style: context.texts.titleLarge),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.edit_rounded,
              title: strings.edit,
              onTap: () => Navigator.pop(context, DeckAction.edit),
            ),
            _ActionTile(
              icon: Icons.subdirectory_arrow_right_rounded,
              title: strings.addSubdeck,
              onTap: () => Navigator.pop(context, DeckAction.addSubdeck),
            ),
            _ActionTile(
              icon: Icons.note_add_rounded,
              title: strings.addCard,
              onTap: () => Navigator.pop(context, DeckAction.addCard),
            ),
            _ActionTile(
              icon: Icons.public_rounded,
              title: strings.share,
              onTap: () => Navigator.pop(context, DeckAction.privacy),
            ),
            _ActionTile(
              icon: Icons.copy_all_rounded,
              title: strings.copyDeck,
              onTap: () => Navigator.pop(context, DeckAction.copy),
            ),
            _ActionTile(
              icon: Icons.drive_file_move_rounded,
              title: strings.moveTo,
              onTap: () => Navigator.pop(context, DeckAction.move),
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              title: strings.delete,
              onTap: () => Navigator.pop(context, DeckAction.delete),
            ),
          ],
        ),
      );
    },
  );
}

Future<CardAction?> showCardActions(BuildContext context) {
  return showModalBottomSheet<CardAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      final AppStrings strings = context.strings;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ActionTile(
              icon: Icons.edit_rounded,
              title: strings.editCard,
              onTap: () => Navigator.pop(context, CardAction.edit),
            ),
            _ActionTile(
              icon: Icons.pause_circle_outline_rounded,
              title: strings.suspend,
              onTap: () => Navigator.pop(context, CardAction.toggleSuspend),
            ),
            _ActionTile(
              icon: Icons.restart_alt_rounded,
              title: strings.resetProgress,
              onTap: () => Navigator.pop(context, CardAction.resetProgress),
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              title: strings.delete,
              onTap: () => Navigator.pop(context, CardAction.delete),
            ),
          ],
        ),
      );
    },
  );
}

Future<DeckPrivacy?> showPrivacySheet(
  BuildContext context, {
  required DeckPrivacy current,
}) {
  return showModalBottomSheet<DeckPrivacy>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      final AppStrings strings = context.strings;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.share, style: context.texts.titleLarge),
            const SizedBox(height: 6),
            Text(strings.publishConfirmBody, style: context.texts.bodySmall),
            const SizedBox(height: 14),
            _PrivacyOption(
              value: DeckPrivacy.private,
              current: current,
              label: strings.privacyPrivate,
              help: strings.privacyPrivateHelp,
              icon: Icons.lock_outline_rounded,
            ),
            _PrivacyOption(
              value: DeckPrivacy.unlisted,
              current: current,
              label: strings.privacyUnlisted,
              help: strings.privacyUnlistedHelp,
              icon: Icons.link_rounded,
            ),
            _PrivacyOption(
              value: DeckPrivacy.public,
              current: current,
              label: strings.privacyPublic,
              help: strings.privacyPublicHelp,
              icon: Icons.public_rounded,
            ),
          ],
        ),
      );
    },
  );
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.value,
    required this.current,
    required this.label,
    required this.help,
    required this.icon,
  });

  final DeckPrivacy value;
  final DeckPrivacy current;
  final String label;
  final String help;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        onTap: () => Navigator.pop(context, value),
        color: selected
            ? context.colors.primaryContainer.withValues(alpha: 0.55)
            : null,
        child: Row(
          children: <Widget>[
            AppIconBadge(icon: icon, size: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: context.texts.titleMedium),
                  const SizedBox(height: 3),
                  Text(help, style: context.texts.bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: context.colors.primary),
          ],
        ),
      ),
    );
  }
}

Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: context.texts.titleLarge),
            const SizedBox(height: 8),
            Text(body, style: context.texts.bodyMedium),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.strings.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: destructive
                        ? FilledButton.styleFrom(
                            backgroundColor: context.colors.error,
                            foregroundColor: context.colors.onError,
                          )
                        : null,
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

Future<DeckDraft?> showDeckEditor(
  BuildContext context, {
  DeckSummary? initial,
  DeckPrivacy initialPrivacy = DeckPrivacy.private,
}) {
  return showModalBottomSheet<DeckDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _DeckEditor(initial: initial, initialPrivacy: initialPrivacy);
    },
  );
}

class _DeckEditor extends StatefulWidget {
  const _DeckEditor({this.initial, required this.initialPrivacy});

  final DeckSummary? initial;
  final DeckPrivacy initialPrivacy;

  @override
  State<_DeckEditor> createState() => _DeckEditorState();
}

class _DeckEditorState extends State<_DeckEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late String _colorHex;
  late String _iconKey;
  late DeckPrivacy _privacy;

  @override
  void initState() {
    super.initState();
    final DeckSummary? initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _tags = TextEditingController(text: initial?.tags.join('، ') ?? '');
    _colorHex = initial?.colorHex ?? _hex(AppColors.deckPalette.first);
    _iconKey = initial?.iconKey ?? 'layers';
    _privacy = initial?.privacy ?? widget.initialPrivacy;
    if (initial != null) {
      _colorHex = initial.colorHex;
    }
  }

  static String _hex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _save() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      DeckDraft(
        title: title,
        description: _description.text.trim(),
        colorHex: _colorHex,
        iconKey: _iconKey,
        tags: _tags.text
            .split(RegExp(r'[,،]'))
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false),
        privacy: _privacy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.initial == null ? strings.createDeck : strings.edit,
              style: context.texts.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.initial == null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.deckTitle,
                hintText: strings.deckTitleHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: strings.description,
                hintText: strings.optional,
              ),
            ),
            const SizedBox(height: 18),
            Text(strings.color, style: context.texts.labelLarge),
            const SizedBox(height: 9),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: AppColors.deckPalette
                  .map((Color color) {
                    final String hex = _hex(color);
                    final bool selected = hex == _colorHex.toUpperCase();
                    return GestureDetector(
                      onTap: () => setState(() => _colorHex = hex),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? context.colors.onSurface
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            Text(strings.icon, style: context.texts.labelLarge),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  <String>[
                        'layers',
                        'bolt',
                        'science',
                        'biotech',
                        'history_edu',
                        'translate',
                        'menu_book',
                        'psychology',
                        'calculate',
                        'code',
                        'palette',
                        'medical',
                        'gavel',
                        'public',
                        'school',
                      ]
                      .map(
                        (String key) => GestureDetector(
                          onTap: () => setState(() => _iconKey = key),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _iconKey == key
                                  ? context.colors.primaryContainer
                                  : context.colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _iconKey == key
                                    ? context.colors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              deckIcon(key),
                              color: _iconKey == key
                                  ? context.colors.onPrimaryContainer
                                  : context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _tags,
              decoration: InputDecoration(
                labelText: strings.tags,
                hintText: strings.tagsHint,
              ),
            ),
            const SizedBox(height: 18),
            Text(strings.share, style: context.texts.labelLarge),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DeckPrivacy.values
                  .map(
                    (DeckPrivacy value) => AppChip(
                      label: switch (value) {
                        DeckPrivacy.private => strings.privacyPrivate,
                        DeckPrivacy.unlisted => strings.privacyUnlisted,
                        DeckPrivacy.public => strings.privacyPublic,
                      },
                      icon: switch (value) {
                        DeckPrivacy.private => Icons.lock_outline_rounded,
                        DeckPrivacy.unlisted => Icons.link_rounded,
                        DeckPrivacy.public => Icons.public_rounded,
                      },
                      selected: _privacy == value,
                      onTap: () => setState(() => _privacy = value),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: _save, child: Text(strings.save)),
          ],
        ),
      ),
    );
  }
}

Future<CardDraft?> showCardEditor(
  BuildContext context, {
  CardSummary? initial,
}) {
  return showModalBottomSheet<CardDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _CardEditor(initial: initial);
    },
  );
}

class _CardEditor extends StatefulWidget {
  const _CardEditor({this.initial});

  final CardSummary? initial;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _hint;
  late final TextEditingController _notes;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    final CardSummary? initial = widget.initial;
    _front = TextEditingController(text: initial?.front ?? '');
    _back = TextEditingController(text: initial?.back ?? '');
    _hint = TextEditingController(text: initial?.hint ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _tags = TextEditingController(text: initial?.tags.join('، ') ?? '');
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _hint.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _save() {
    final String front = _front.text.trim();
    final String back = _back.text.trim();
    if (front.isEmpty || back.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      CardDraft(
        front: front,
        back: back,
        hint: _hint.text.trim(),
        notes: _notes.text.trim(),
        tags: _tags.text
            .split(RegExp(r'[,،]'))
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.initial == null ? strings.addCard : strings.editCard,
              style: context.texts.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _front,
              autofocus: widget.initial == null,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: strings.front,
                hintText: strings.frontHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _back,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: strings.back,
                hintText: strings.backHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hint,
              decoration: InputDecoration(
                labelText: strings.hint,
                hintText: strings.hintHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: strings.notes,
                hintText: strings.notesHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: InputDecoration(
                labelText: strings.tags,
                hintText: strings.tagsHint,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: _save, child: Text(strings.save)),
          ],
        ),
      ),
    );
  }
}

Future<List<ImportedCard>?> showImportSheet(BuildContext context) {
  return showModalBottomSheet<List<ImportedCard>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => const _ImportSheet(),
  );
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final List<ImportedCard> cards = <ImportedCard>[];
    for (final String line in _controller.text.split('\n')) {
      final String clean = line.trim();
      if (clean.isEmpty) {
        continue;
      }
      final List<String> parts = clean
          .split(RegExp(r'\s*[|;]\s*'))
          .map((String value) => value.trim())
          .toList(growable: false);
      if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
        continue;
      }
      cards.add(
        ImportedCard(
          front: parts[0],
          back: parts[1],
          hint: parts.length > 2 ? parts[2] : '',
        ),
      );
    }
    if (cards.isEmpty) {
      return;
    }
    Navigator.pop(context, cards);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.importTitle, style: context.texts.titleLarge),
            const SizedBox(height: 6),
            Text(strings.importHint, style: context.texts.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 8,
              maxLines: 14,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(hintText: strings.importFormatHelp),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: Text(strings.import)),
          ],
        ),
      ),
    );
  }
}

Future<DeckChoice?> showDeckPicker(
  BuildContext context, {
  required List<DeckSummary> decks,
  Set<String> excludeIds = const <String>{},
  String? title,
}) {
  return showModalBottomSheet<DeckChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _DeckPicker(decks: decks, excludeIds: excludeIds, title: title);
    },
  );
}

class _DeckPicker extends StatefulWidget {
  const _DeckPicker({
    required this.decks,
    required this.excludeIds,
    this.title,
  });

  final List<DeckSummary> decks;
  final Set<String> excludeIds;
  final String? title;

  @override
  State<_DeckPicker> createState() => _DeckPickerState();
}

class _DeckPickerState extends State<_DeckPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<DeckSummary> filtered = widget.decks
        .where((DeckSummary deck) => !widget.excludeIds.contains(deck.id))
        .where(
          (DeckSummary deck) =>
              _query.isEmpty ||
              deck.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title ?? strings.selectParent,
              style: context.texts.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: strings.searchDecks,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: <Widget>[
                  ListTile(
                    onTap: () => Navigator.pop(context, const DeckChoice(null)),
                    leading: const Icon(Icons.home_work_outlined),
                    title: Text(strings.rootLevel),
                    subtitle: Text(strings.noParent),
                  ),
                  const Divider(),
                  ...filtered.map(
                    (DeckSummary deck) => Padding(
                      padding: EdgeInsets.only(
                        left: context.isArabic ? 0 : deck.depth * 16,
                        right: context.isArabic ? deck.depth * 16 : 0,
                      ),
                      child: ListTile(
                        onTap: () =>
                            Navigator.pop(context, DeckChoice(deck.id)),
                        leading: AppIconBadge(
                          icon: deckIcon(deck.iconKey),
                          color: AppColors.fromHex(deck.colorHex),
                          size: 38,
                          radius: 11,
                        ),
                        title: Text(
                          deck.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          context.strings.cardsCount(deck.cardCount),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData deckIcon(String key) {
  return getDeckIcon(key);
}
IconData deckIcon(String key) => getDeckIcon(key);
