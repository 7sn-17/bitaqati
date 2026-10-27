import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/card_markup.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/content_providers.dart';
import '../../data/library_providers.dart';
import '../../data/library_repository.dart';
import '../../data/sharing_providers.dart';
import '../../data/sharing_service.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../create/deck_editor_sheet.dart';
import '../create/editor_common.dart';
import '../library/install_library_deck.dart';

/// A deck screen with two strict modes, matching the two-level hierarchy:
///
/// * A **main deck** (depth 0) lists sub-decks only, and its only creation
///   action is "new sub-deck". It can never receive a card.
/// * A **sub-deck** (depth 1) lists cards only, and its only creation action is
///   "new card". It can never receive a sub-deck.
///
/// Public-library decks are previews and are read-only in both modes.
class DeckDetailScreen extends ConsumerStatefulWidget {
  const DeckDetailScreen({required this.deckId, super.key});

  final String deckId;

  @override
  ConsumerState<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends ConsumerState<DeckDetailScreen> {
  int _tab = 0;
  String _query = '';
  bool _installing = false;
  bool _publishing = false;
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final DeckNode? local = ref.watch(deckByIdProvider(widget.deckId));
    final AsyncValue<DeckNode?> remote = local == null
        ? ref.watch(libraryDeckProvider(widget.deckId))
        : const AsyncData<DeckNode?>(null);
    final DeckNode? found = local ?? remote.valueOrNull;
    if (found == null) {
      return _MissingDeck(
        loading:
            ref.watch(deckListProvider).isLoading || remote.isLoading,
      );
    }

    final DeckNode deck = found;
    final bool isPreview = local == null;

    final List<ReviewCard> cards =
        ref.watch(deckCardsProvider(deck.id)).valueOrNull ??
        const <ReviewCard>[];
    final List<ReviewCard> visibleCards = _matching(cards);
    final bool canStudy =
        !isPreview && deck.cardCount > 0 && deck.dueCount > 0;
    final String studyLabel = isPreview
        ? (_installing ? 'جارٍ الإضافة' : 'أضف نسخة إلى مجموعاتي')
        : deck.cardCount == 0
        ? 'لا بطاقات للمراجعة بعد'
        : deck.dueCount == 0
        ? 'لا بطاقات مستحقة الآن'
        : 'ادرس هذه المجموعة · ${deck.dueCount} مستحقة';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 26),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  _RoundButton(
                    icon: CupertinoIcons.chevron_forward,
                    label: 'رجوع',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const Spacer(),
                  if (!isPreview)
                    _RoundButton(
                      icon: CupertinoIcons.ellipsis,
                      label: 'المزيد',
                      onTap: () => _showActions(context, deck),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      deck.color,
                      deck.color.withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(deck.icon, color: Colors.white, size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            deck.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isPreview
                                ? '${deck.cardCount} بطاقة · '
                                      '${deck.author ?? 'مجموعة مشاركة'}'
                                : '${deck.cardCount} بطاقة · '
                                      'نسبة الحفظ ${deck.retention.round()}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (deck.rating != null)
                      Row(
                        children: <Widget>[
                          const Icon(
                            CupertinoIcons.star_fill,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            deck.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniStat(
                      value: '${deck.dueNew}',
                      label: 'جديدة',
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      value: '${deck.dueLearning}',
                      label: 'تعلّم',
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      value: '${deck.dueReview}',
                      label: 'مراجعة',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPreview
                      ? (_installing
                            ? null
                            : () => _installPreview(context, deck))
                      : (canStudy
                            ? () => context.push('/review/${deck.id}')
                            : null),
                  style: FilledButton.styleFrom(
                    backgroundColor: isPreview
                        ? AppColors.primary
                        : AppColors.accent,
                    foregroundColor: isPreview
                        ? AppColors.accent
                        : AppColors.primary,
                  ),
                  child: _installing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.accent,
                          ),
                        )
                      : Text(studyLabel),
                ),
              ),
            ),
            if (!isPreview && deck.cardCount == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'أضف أول بطاقة من الزر أدناه لتبدأ المراجعة.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall,
                ),
              )
            else if (!isPreview && deck.dueCount == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'كل البطاقات مجدولة الآن. عد لاحقاً أو أضف بطاقات جديدة.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            if (isPreview)
              _PreviewPanel(deck: deck)
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Tabs(
                  selected: _tab,
                  firstLabel: 'البطاقات',
                  onChanged: (int value) => setState(() {
                    _tab = value;
                    _selecting = false;
                    _selected.clear();
                  }),
                ),
              ),
              const SizedBox(height: 14),
              if (_tab == 0)
                ..._cardSection(context, deck, cards, visibleCards)
              else if (_tab == 1)
                _DeckStatisticsTab(deck: deck)
              else
                ..._settingsSection(context, deck),
            ],
          ],
        ),
      ),
      bottomNavigationBar: isPreview
          ? null
          : _selecting
          ? _BulkActionBar(
              count: _selected.length,
              onCancel: _clearSelection,
              onMove: () => _moveSelected(context, deck),
              onTag: () => _tagSelected(context),
              onSuspend: () => _suspendSelected(context),
              onDelete: () => _deleteSelected(context),
            )
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _addCard(context, deck),
                    icon: const Icon(CupertinoIcons.plus, size: 18),
                    label: const Text('بطاقة جديدة'),
                  ),
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  List<Widget> _cardSection(
    BuildContext context,
    DeckNode deck,
    List<ReviewCard> cards,
    List<ReviewCard> visibleCards,
  ) {
    if (cards.isEmpty) {
      return <Widget>[
        _EmptyState(
          icon: CupertinoIcons.rectangle_stack,
          title: 'لا بطاقات بعد',
          body:
              'هذه المجموعة جاهزة لبطاقاتك. أضف أول بطاقة '
              'لتظهر في المراجعة.',
          actionLabel: 'إضافة بطاقة',
          onAction: () => _addCard(context, deck),
        ),
      ];
    }
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث في البطاقات',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                  suffixIcon: _selecting
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _selecting = true),
                          tooltip: 'تحديد متعدد',
                          icon: const Icon(
                            CupertinoIcons.checkmark_circle,
                            size: 19,
                          ),
                        ),
                ),
              ),
            ),
            if (_selecting) ...<Widget>[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearSelection,
                child: const Text('إلغاء'),
              ),
            ],
          ],
        ),
      ),
      if (_selecting) ...<Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Row(
            children: <Widget>[
              Text(
                '${_selected.length} محددة',
                style: context.texts.labelLarge,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == visibleCards.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(
                          visibleCards.map((ReviewCard card) => card.id),
                        );
                    }
                  });
                },
                child: Text(
                  _selected.length == visibleCards.length
                      ? 'إلغاء الكل'
                      : 'تحديد الكل',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (visibleCards.isEmpty)
        Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            'لا نتائج مطابقة لبحثك.',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall,
          ),
        )
      else
        for (int index = 0; index < visibleCards.length; index++)
          _SelectableCardRow(
            card: visibleCards[index],
            index: index,
            selected: _selected.contains(visibleCards[index].id),
            selecting: _selecting,
            onTap: () {
              if (_selecting) {
                _toggleCard(visibleCards[index].id);
              } else {
                _editCard(context, visibleCards[index]);
              }
            },
            onLongPress: () {
              if (!_selecting) {
                setState(() {
                  _selecting = true;
                  _selected.add(visibleCards[index].id);
                });
              } else {
                _toggleCard(visibleCards[index].id);
              }
            },
          ),
    ];
  }

  void _toggleCard(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
      if (_selected.isEmpty) {
        _selecting = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  Future<void> _moveSelected(BuildContext context, DeckNode deck) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل البطاقات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    final List<DeckNode> targets = ref
        .read(allDecksProvider)
        .where((DeckNode node) => node.id != deck.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      showAppMessage(
        context,
        'لا توجد مجموعة أخرى لنقل البطاقات إليها.',
        kind: AppMessageKind.info,
      );
      return;
    }
    final String? target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheet) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                child: Text(
                  'نقل ${_selected.length} بطاقة إلى',
                  style: context.texts.titleMedium,
                ),
              ),
              for (final DeckNode node in targets)
                ListTile(
                  leading: Icon(
                    kDeckIcons[node.iconKey] ?? CupertinoIcons.folder,
                    color: node.color,
                  ),
                  title: Text(node.title),
                  subtitle: Text('${node.cardCount} بطاقة'),
                  onTap: () => Navigator.of(sheet).pop(node.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (target == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(contentRepositoryProvider).moveCards(
        cardIds: _selected.toList(growable: false),
        deckId: target,
      );
      if (!mounted || !context.mounted) {
        return;
      }
      showAppMessage(context, 'تم نقل البطاقات.');
      _clearSelection();
    } catch (_) {
      if (mounted && context.mounted) {
        showAppMessage(
          context,
          'تعذّر نقل البطاقات. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  Future<void> _tagSelected(BuildContext context) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل البطاقات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    final TextEditingController controller = TextEditingController();
    final String? raw = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إضافة وسوم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'وسم، وسم آخر',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    final List<String> tags = parseTags(raw ?? '');
    if (tags.isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref.read(contentRepositoryProvider).addTagsToCards(
        cardIds: _selected.toList(growable: false),
        tags: tags,
      );
      if (!mounted || !context.mounted) {
        return;
      }
      showAppMessage(context, 'تمت إضافة الوسوم.');
      _clearSelection();
    } catch (_) {
      if (mounted && context.mounted) {
        showAppMessage(
          context,
          'تعذّرت إضافة الوسوم. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  Future<void> _suspendSelected(BuildContext context) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل البطاقات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    try {
      await ref.read(contentRepositoryProvider).setCardsSuspended(
        cardIds: _selected.toList(growable: false),
        suspended: true,
      );
      if (!mounted || !context.mounted) {
        return;
      }
      showAppMessage(context, 'تم تعليق البطاقات.');
      _clearSelection();
    } catch (_) {
      if (mounted && context.mounted) {
        showAppMessage(
          context,
          'تعذّر تعليق البطاقات. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  Future<void> _deleteSelected(BuildContext context) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل البطاقات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text('حذف ${_selected.length} بطاقة؟'),
        content: const Text(
          'سيتم حذف البطاقات المحددة من هذه المجموعة. '
          'يمكنك الاحتفاظ بسجل المراجعة في الإحصائيات.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(contentRepositoryProvider).deleteCards(
        _selected.toList(growable: false),
      );
      if (!mounted || !context.mounted) {
        return;
      }
      showAppMessage(context, 'تم حذف البطاقات.');
      _clearSelection();
    } catch (_) {
      if (mounted && context.mounted) {
        showAppMessage(
          context,
          'تعذّر حذف البطاقات. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _addCard(BuildContext context, DeckNode deck) async {
    if (!ensureCanCreate(context, ref)) {
      return;
    }
    final String? message = await context.push<String>(
      '/create-card?deckId=${deck.id}',
    );
    if (message != null && context.mounted) {
      showAppMessage(context, message);
    }
  }

  Future<void> _editCard(BuildContext context, ReviewCard card) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل البطاقات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    final String? message = await context.push<String>(
      '/edit-card/${card.id}?deckId=${card.deckId}',
    );
    if (message != null && context.mounted) {
      showAppMessage(context, message);
    }
  }

  void _showActions(BuildContext screenContext, DeckNode deck) {
    showModalBottomSheet<void>(
      context: screenContext,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(CupertinoIcons.pencil),
                title: const Text('تعديل المجموعة'),
                onTap: () {
                  Navigator.of(context).pop();
                  _editDeck(screenContext, deck);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.gear),
                title: const Text('الإعدادات والمشاركة'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _tab = 2);
                },
              ),
              if (deck.isPublished)
                ListTile(
                  leading: const Icon(CupertinoIcons.link),
                  title: const Text('نسخ رابط المشاركة'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _copyLink(screenContext, deck);
                  },
                ),
              if (deck.isPublished && deck.isShareable)
                ListTile(
                  leading: const Icon(CupertinoIcons.number),
                  title: Text('نسخ رمز المشاركة · ${deck.shareCode}'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _copyCode(screenContext, deck);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _editDeck(BuildContext context, DeckNode deck) {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'تعديل المجموعات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    showDeckEditorSheet(context, deck: deck);
  }

  Future<void> _installPreview(BuildContext context, DeckNode deck) async {
    if (_installing) {
      return;
    }
    setState(() => _installing = true);
    final String? localId = await installLibraryDeck(context, ref, deck);
    if (!mounted || !context.mounted) {
      return;
    }
    setState(() => _installing = false);
    if (localId != null) {
      context.pushReplacement('/deck/$localId');
    }
  }

  Future<void> _setPrivacy(
    BuildContext context,
    DeckNode deck,
    DeckPrivacy privacy,
  ) async {
    if (_publishing || deck.privacy == privacy) {
      return;
    }
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'نشر المجموعات ومشاركتها يحتاج حساباً. '
          'سجّل الدخول بحساب Google من الإعدادات.',
    )) {
      return;
    }
    setState(() => _publishing = true);
    try {
      final SharingService sharing = ref.read(sharingServiceProvider);
      String? code;
      if (privacy == DeckPrivacy.private) {
        await sharing.unpublish(deck.id);
      } else {
        final SharingResult result = await sharing.publish(
          deckId: deck.id,
          privacy: privacy,
        );
        code = result.shareCode;
      }
      if (!mounted || !context.mounted) {
        return;
      }
      showAppMessage(
        context,
        privacy == DeckPrivacy.private
            ? 'تم إيقاف المشاركة. أصبحت المجموعة خاصة.'
            : 'تم النشر. رمز المشاركة ${code ?? ''}',
      );
    } on SharingFailure catch (error) {
      if (mounted && context.mounted) {
        showAppMessage(context, error.message, kind: AppMessageKind.error);
      }
    } catch (_) {
      if (mounted && context.mounted) {
        showAppMessage(
          context,
          'تعذّر تحديث حالة المشاركة. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<void> _copyLink(BuildContext context, DeckNode deck) async {
    final String link = AppConfig.deckShareLink(deck.id);
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      showAppMessage(context, 'تم نسخ رابط المشاركة.');
    }
  }

  Future<void> _copyCode(BuildContext context, DeckNode deck) async {
    final String? code = deck.shareCode;
    if (code == null || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      showAppMessage(context, 'تم نسخ الرمز $code.');
    }
  }

  Future<void> _confirmDelete(BuildContext context, DeckNode deck) async {
    if (!ensureSignedIn(
      context,
      ref,
      message:
          'حذف المجموعات يحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
    )) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('حذف المجموعة؟'),
        content: Text(
          'سيتم حذف «${deck.title}» وكل بطاقاتها. '
          'لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(contentRepositoryProvider).deleteDeck(deck.id);
      if (!mounted || !context.mounted) {
        return;
      }
      showAppMessage(context, 'تم حذف المجموعة.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (mounted && context.mounted) {
        showAppMessage(
          context,
          'تعذّر حذف المجموعة. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  List<Widget> _settingsSection(BuildContext context, DeckNode deck) {
    final bool signedIn =
        ref.watch(currentUserProvider).valueOrNull != null;
    return <Widget>[
      const SizedBox(height: 8),
      const SectionHeader(
        title: 'الإعدادات والمشاركة',
        subtitle: 'عدّل هوية المجموعة وتحكّم في من يمكنه الوصول إليها.',
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SurfaceCard(
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: deck.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  kDeckIcons[deck.iconKey] ?? CupertinoIcons.rectangle_stack,
                  color: deck.color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(deck.title, style: context.texts.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'تعديل الاسم واللون والأيقونة',
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _editDeck(context, deck),
                child: const Text('تعديل'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _PrivacyCard(
          deck: deck,
          signedIn: signedIn,
          publishing: _publishing,
          onSelect: (DeckPrivacy privacy) =>
              _setPrivacy(context, deck, privacy),
          onCopy: () => _copyLink(context, deck),
          onCopyCode: () => _copyCode(context, deck),
        ),
      ),
      if (deck.sourceDeckId != null) ...<Widget>[
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'تقييم المجموعة الأصلية',
                  style: context.texts.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'ساعد الآخرين على اختيار مجموعات جيدة.',
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: 10),
                _DeckRatingBar(
                  deck: DeckNode(
                    id: deck.sourceDeckId!,
                    title: deck.title,
                    color: deck.color,
                    isPublic: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'منطقة الخطر',
                style: context.texts.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'حذف المجموعة يحذف بطاقاتها وسجل مراجعتها.',
                style: context.texts.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, deck),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('حذف المجموعة'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 26),
    ];
  }

  List<ReviewCard> _matching(List<ReviewCard> cards) {
    final String needle = _query.trim();
    if (needle.isEmpty) {
      return cards;
    }
    return cards
        .where(
          (ReviewCard card) =>
              card.front.contains(needle) ||
              card.back.contains(needle) ||
              card.tags.any((String tag) => tag.contains(needle)),
        )
        .toList(growable: false);
  }

}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: context.texts.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SurfaceCard(
        child: Column(
          children: <Widget>[
            Icon(icon, size: 34, color: context.colors.primary),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(CupertinoIcons.plus, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.firstLabel,
    required this.onChanged,
  });

  final int selected;
  final String firstLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[firstLabel, 'إحصائيات', 'الإعدادات'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < labels.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == index
                        ? context.colors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected == index
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == index
                          ? (context.isDark ? AppColors.primary : Colors.white)
                          : context.texts.bodySmall?.color,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _cardPreviewText(String raw, {String fallback = ''}) {
  final String value = raw.trim();
  if (value.isEmpty) {
    return fallback;
  }
  if (isImageOnly(value)) {
    return 'صورة تغطية';
  }
  if (RegExp(r'^\[(?:صوت|sound)[^\]]*\]\([^)]+\)$').hasMatch(value)) {
    return 'مرفق صوتي';
  }
  final String plain = plainMarkup(value);
  return plain.isEmpty ? fallback : plain;
}

class _SelectableCardRow extends StatelessWidget {
  const _SelectableCardRow({
    required this.card,
    required this.index,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final ReviewCard card;
  final int index;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final _CardStatusInfo status = _statusFor(card);
    final String front = _cardPreviewText(card.front, fallback: 'بدون نص');
    final String back = _cardPreviewText(card.back);
    final bool hasBack = back.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: selected ? context.softAccent : context.cardSurface,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? context.brandInk.withValues(alpha: 0.55)
                      : context.hairline,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // State stripe: the fastest way to read a long list.
                  Container(
                    width: 4,
                    color: status.color.withValues(
                      alpha: context.isDark ? 0.85 : 0.9,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _SelectionMark(
                                index: index,
                                selected: selected,
                                selecting: selecting,
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(info: status),
                              if (card.type != 'basic') ...<Widget>[
                                const SizedBox(width: 5),
                                _TypeBadge(type: card.type),
                              ],
                              const Spacer(),
                              if (card.favorite)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 4,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.star_fill,
                                    size: 13,
                                    color: context.brandInk,
                                  ),
                                ),
                              if (card.tags.isNotEmpty)
                                Icon(
                                  CupertinoIcons.tag,
                                  size: 13,
                                  color: context.texts.bodySmall?.color,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            front,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.titleMedium?.copyWith(
                              fontSize: 15,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                              color: context.ink,
                            ),
                          ),
                          if (hasBack) ...<Widget>[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              decoration: BoxDecoration(
                                color: context.raisedSurface,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(
                                      CupertinoIcons.arrow_turn_down_left,
                                      size: 12,
                                      color: context.texts.bodySmall?.color,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      back,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.bodySmall?.copyWith(
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (card.tags.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: <Widget>[
                                for (final String tag in card.tags.take(4))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.softAccent,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: context.brandInk,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _CardStatusInfo _statusFor(ReviewCard card) {
    if (card.suspended) {
      return const _CardStatusInfo(
        label: 'معلّقة',
        color: Color(0xFF7C6AAE),
        icon: CupertinoIcons.pause_circle,
      );
    }
    if (card.isLeech) {
      return const _CardStatusInfo(
        label: 'تحتاج تركيزاً',
        color: AppColors.danger,
        icon: CupertinoIcons.exclamationmark_triangle,
      );
    }
    if (card.phase == CardPhase.newCard) {
      return const _CardStatusInfo(
        label: 'جديدة',
        color: AppColors.blue,
        icon: CupertinoIcons.sparkles,
      );
    }
    if (card.isDue) {
      return const _CardStatusInfo(
        label: 'مستحقة',
        color: AppColors.accent,
        icon: CupertinoIcons.clock,
      );
    }
    if (card.phase == CardPhase.learning) {
      return const _CardStatusInfo(
        label: 'قيد التعلّم',
        color: AppColors.danger,
        icon: CupertinoIcons.flame,
      );
    }
    return const _CardStatusInfo(
      label: 'راسخة',
      color: AppColors.primary,
      icon: CupertinoIcons.checkmark_seal,
    );
  }
}

class _CardStatusInfo {
  const _CardStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

/// Index chip that turns into a checkbox while a selection is active.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    required this.index,
    required this.selected,
    required this.selecting,
  });

  final int index;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? context.brandInk : context.raisedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: selecting
          ? Icon(
              selected ? CupertinoIcons.checkmark_alt : CupertinoIcons.circle,
              size: 14,
              color: selected
                  ? (context.isDark ? AppColors.primary : Colors.white)
                  : context.texts.bodySmall?.color,
            )
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.texts.bodySmall?.color,
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.info});

  final _CardStatusInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: context.isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(info.icon, size: 10, color: info.color),
          const SizedBox(width: 3),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final String label;
    switch (type) {
      case 'cloze':
        label = 'ملء فراغ';
      case 'occlusion':
        label = 'تغطية';
      case 'mcq':
        label = 'اختيار';
      default:
        label = 'أساسية';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.texts.bodySmall?.copyWith(fontSize: 9),
      ),
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.count,
    required this.onCancel,
    required this.onMove,
    required this.onTag,
    required this.onSuspend,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onMove;
  final VoidCallback onTag;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkSurfaceHigh : Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onCancel,
                icon: const Icon(CupertinoIcons.xmark, size: 18),
                tooltip: 'إلغاء التحديد',
              ),
              Expanded(
                child: Text(
                  '$count محددة',
                  style: context.texts.labelLarge,
                ),
              ),
              _BulkAction(
                icon: CupertinoIcons.folder,
                label: 'نقل',
                onTap: onMove,
              ),
              _BulkAction(
                icon: CupertinoIcons.tag,
                label: 'وسم',
                onTap: onTag,
              ),
              _BulkAction(
                icon: CupertinoIcons.pause,
                label: 'تعليق',
                onTap: onSuspend,
              ),
              _BulkAction(
                icon: CupertinoIcons.trash,
                label: 'حذف',
                color: AppColors.danger,
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkAction extends StatelessWidget {
  const _BulkAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? context.colors.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 19, color: tint),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.deck});

  final DeckNode deck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  CupertinoIcons.book,
                  size: 20,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'معاينة من المكتبة',
                    style: context.texts.titleMedium,
                  ),
                ),
                if (deck.rating != null)
                  Text(
                    '${deck.rating!.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${deck.cardCount} بطاقة'
              '${deck.author != null ? ' · بواسطة ${deck.author}' : ''}',
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'أضف نسخة إلى مساحتك لتدرسها وتعدّلها بحرية. '
              'لن تتأثر النسخة الأصلية بتعديلاتك.',
              style: context.texts.bodySmall?.copyWith(height: 1.65),
            ),
            if (deck.isPublic) ...<Widget>[
              const SizedBox(height: 12),
              _DeckRatingBar(deck: deck),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckRatingBar extends ConsumerStatefulWidget {
  const _DeckRatingBar({required this.deck});

  final DeckNode deck;

  @override
  ConsumerState<_DeckRatingBar> createState() => _DeckRatingBarState();
}

class _DeckRatingBarState extends ConsumerState<_DeckRatingBar> {
  bool _saving = false;

  Future<void> _rate(int rating) async {
    if (_saving) {
      return;
    }
    if (!ensureSignedIn(
      context,
      ref,
      message: 'تقييم المجموعات يحتاج حساباً. سجّل الدخول بحساب Google.',
    )) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .rateDeck(widget.deck.id, rating);
      if (!mounted) {
        return;
      }
      ref.invalidate(myDeckRatingProvider(widget.deck.id));
      ref.invalidate(libraryBundleProvider(widget.deck.id));
      ref.invalidate(libraryDeckProvider(widget.deck.id));
      ref.invalidate(libraryDecksProvider);
      showAppMessage(context, 'شكراً لتقييمك.');
    } on LibraryFailure catch (error) {
      if (mounted) {
        showAppMessage(context, error.message, kind: AppMessageKind.error);
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'تعذّر حفظ التقييم. حاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int mine = ref.watch(myDeckRatingProvider(widget.deck.id)).valueOrNull ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                for (int star = 1; star <= 5; star++)
                  GestureDetector(
                    onTap: _saving ? null : () => _rate(star),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 1, right: 1),
                      child: Icon(
                        star <= mine
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.star,
                        size: 18,
                        color: star <= mine
                            ? AppColors.accent
                            : context.colors.outlineVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.deck.rating != null)
            Text(
              '${widget.deck.rating!.toStringAsFixed(1)}'
              ' (${widget.deck.ratingCount})',
              style: context.texts.bodySmall?.copyWith(fontSize: 10.5),
            )
          else
            Text('قيّم المجموعة', style: context.texts.bodySmall),
        ],
      ),
    );
  }
}

class _DeckStatisticsTab extends ConsumerWidget {
  const _DeckStatisticsTab({required this.deck});

  final DeckNode deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DeckStatistics> stats = ref.watch(
      deckStatisticsProvider(deck.id),
    );
    return stats.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 54),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SurfaceCard(
          child: Column(
            children: <Widget>[
              const Icon(CupertinoIcons.exclamationmark_circle, size: 32),
              const SizedBox(height: 8),
              Text('تعذّر تحميل الإحصائيات', style: context.texts.titleMedium),
              const SizedBox(height: 4),
              Text(
                'حاول إعادة فتح المجموعة.',
                style: context.texts.bodySmall,
              ),
            ],
          ),
        ),
      ),
      data: (DeckStatistics value) {
        if (value.totalCards == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: _EmptyState(
              icon: CupertinoIcons.chart_bar,
              title: 'لا إحصائيات بعد',
              body: 'أضف بطاقات وابدأ المراجعة لتظهر الأرقام الحقيقية هنا.',
              actionLabel: 'إضافة بطاقة',
              onAction: () async {
                if (!ensureCanCreate(context, ref)) {
                  return;
                }
                final String? message = await context.push<String>(
                  '/create-card?deckId=${deck.id}',
                );
                if (message != null && context.mounted) {
                  showAppMessage(context, message);
                }
              },
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.primary, Color(0xFF2D5410)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          CircularProgressIndicator(
                            value: value.retention / 100,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                          Center(
                            child: Text(
                              '${value.retention.round()}%',
                              style: const TextStyle(
                                fontFamily: 'ReadexPro',
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'نسبة التذكر',
                            style: TextStyle(
                              fontFamily: 'ReadexPro',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value.reviewCount == 0
                                ? 'لم تُراجع أي بطاقة بعد.'
                                : '${value.correctCount} إجابة صحيحة من '
                                      '${value.reviewCount} مراجعة.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11.5,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _StatBox(
                    value: '${value.totalCards}',
                    label: 'إجمالي البطاقات',
                    color: AppColors.primary,
                  ),
                  _StatBox(
                    value: '${value.newCards}',
                    label: 'جديدة',
                    color: AppColors.blue,
                  ),
                  _StatBox(
                    value: '${value.learningCards}',
                    label: 'قيد التعلّم',
                    color: AppColors.danger,
                  ),
                  _StatBox(
                    value: '${value.dueCards}',
                    label: 'مستحقة الآن',
                    color: AppColors.accent,
                  ),
                  _StatBox(
                    value: '${value.matureCards}',
                    label: 'ناضجة',
                    color: const Color(0xFF4E7A2A),
                  ),
                  _StatBox(
                    value: '${value.maturityPercent.round()}%',
                    label: 'اكتمال النضج',
                    color: const Color(0xFF6B5B95),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 50) / 2,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ReadexPro',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.texts.bodySmall),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.deck,
    required this.signedIn,
    required this.publishing,
    required this.onSelect,
    required this.onCopy,
    required this.onCopyCode,
  });

  final DeckNode deck;
  final bool signedIn;
  final bool publishing;
  final ValueChanged<DeckPrivacy> onSelect;
  final VoidCallback onCopy;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    final String link = AppConfig.deckShareLink(deck.id);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.square_arrow_up,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('الخصوصية والمشاركة', style: context.texts.titleMedium),
                    const SizedBox(height: 1),
                    Text(
                      'انشر المجموعة لمشاركتها برابط أو برمز.',
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              if (publishing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
            ],
          ),
          if (!signedIn) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(
                  alpha: context.isDark ? 0.15 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سجّل الدخول بحساب Google للنشر والمشاركة.',
                      style: context.texts.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final DeckPrivacy privacy in DeckPrivacy.values)
            _PrivacyOption(
              privacy: privacy,
              selected: deck.privacy == privacy,
              enabled: signedIn && !publishing,
              onTap: () => onSelect(privacy),
            ),
          if (deck.isPublished) ...<Widget>[
            if (deck.isShareable) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft.withValues(
                    alpha: context.isDark ? 0.2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'رمز المشاركة',
                          style: context.texts.labelSmall?.copyWith(
                            color: context.isDark
                                ? AppColors.darkMuted
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          deck.shareCode!,
                          style: const TextStyle(
                            fontFamily: 'ReadexPro',
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onCopyCode,
                      icon: const Icon(CupertinoIcons.doc_on_doc, size: 14),
                      label: const Text('نسخ'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      link,
                      maxLines: 2,
                      style: context.texts.bodySmall?.copyWith(
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 14),
                    label: const Text('نسخ'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.privacy,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DeckPrivacy privacy;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (privacy) {
      case DeckPrivacy.private:
        icon = CupertinoIcons.lock;
      case DeckPrivacy.unlisted:
        icon = CupertinoIcons.link;
      case DeckPrivacy.public:
        icon = CupertinoIcons.globe;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentSoft.withValues(
                    alpha: context.isDark ? 0.18 : 1,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : context.colors.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 17,
                color: selected
                    ? AppColors.primary
                    : context.texts.bodySmall?.color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      privacy.labelAr,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : context.colors.onSurface,
                      ),
                    ),
                    Text(
                      privacy.descriptionAr,
                      style: context.texts.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 18,
                color: selected
                    ? AppColors.primary
                    : context.colors.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: context.colors.onSurface),
        ),
      ),
    );
  }
}

class _MissingDeck extends StatelessWidget {
  const _MissingDeck({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        CupertinoIcons.rectangle_stack,
                        size: 40,
                        color: context.texts.bodySmall?.color,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لم نعثر على هذه المجموعة',
                        style: context.texts.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                        child: const Text('رجوع'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
