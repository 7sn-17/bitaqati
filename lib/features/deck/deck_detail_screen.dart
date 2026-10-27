import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/content_providers.dart';
import '../../data/library_demo.dart';
import '../../domain/models.dart';
import '../create/card_editor_sheet.dart';
import '../create/deck_editor_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final DeckNode? found =
        ref.watch(deckByIdProvider(widget.deckId)) ??
        findLibraryDeck(widget.deckId);
    if (found == null) {
      return _MissingDeck(loading: ref.watch(deckListProvider).isLoading);
    }

    final DeckNode deck = found;
    final bool isPreview = deck.isPreview;
    final bool isSubDeck = !isPreview && deck.isSubDeck;
    final String? parentId = deck.parentId;
    final DeckNode? parent = isSubDeck && parentId != null
        ? ref.watch(deckByIdProvider(parentId))
        : null;

    // Only sub-decks read cards; only main decks read sub-decks. Each mode
    // ignores the other side of the hierarchy entirely.
    final List<ReviewCard> cards = isSubDeck
        ? (ref.watch(deckCardsProvider(deck.id)).valueOrNull ??
              const <ReviewCard>[])
        : const <ReviewCard>[];
    final List<ReviewCard> visibleCards = _matching(cards);
    final List<DeckNode> subDecks = isSubDeck
        ? const <DeckNode>[]
        : deck.children;

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
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          deck.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.headlineSmall,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _headerSubtitle(
                            deck,
                            isSubDeck,
                            cards.length,
                            isPreview,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!isPreview)
                    _RoundButton(
                      icon: CupertinoIcons.ellipsis,
                      label: 'المزيد',
                      onTap: () => _showActions(context, deck),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isSubDeck && parent != null) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ParentChip(
                  parent: parent,
                  onTap: () => context.push('/deck/${parent.id}'),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
                            _heroTitle(deck, isSubDeck, isPreview),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPreview
                                ? '${deck.cardCount} بطاقة · ${deck.author}'
                                : 'نسبة الحفظ ${deck.retention.round()}% · '
                                      '${deck.dueCount} مستحقة',
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
                            '${deck.rating}',
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
                      ? () => _showPreviewNotice(context)
                      : (deck.cardCount == 0
                            ? null
                            : () => context.push('/review/${deck.id}')),
                  style: FilledButton.styleFrom(
                    backgroundColor: isPreview
                        ? AppColors.primary
                        : AppColors.accent,
                    foregroundColor: isPreview
                        ? AppColors.accent
                        : AppColors.primary,
                  ),
                  child: Text(
                    isPreview
                        ? 'أضف نسخة إلى مجموعاتي'
                        : (deck.cardCount == 0
                              ? 'لا بطاقات للمراجعة بعد'
                              : 'ادرس هذه المجموعة'),
                  ),
                ),
              ),
            ),
            if (!isPreview && deck.cardCount == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  isSubDeck ? 'أضف أول بطاقة من الزر أدناه لتبدأ المراجعة.' : 'أنشئ مجموعة فرعية، ثم أضف البطاقات داخلها لتبدأ المراجعة.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            if (isPreview)
              const _TabPlaceholder(
                icon: CupertinoIcons.book,
                title: 'مجموعة من المكتبة العامة',
                body: 'هذه معاينة فقط: لا يمكن دراستها أو تعديلها قبل ربط المكتبة العامة بالسحابة.',
              )
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Tabs(
                  selected: _tab,
                  firstLabel: isSubDeck ? 'البطاقات' : 'المجموعات الفرعية',
                  onChanged: (int value) => setState(() => _tab = value),
                ),
              ),
              const SizedBox(height: 14),
              if (_tab == 0)
                ...(isSubDeck
                    ? _cardSection(context, deck, cards, visibleCards)
                    : _subDeckSection(context, deck, subDecks))
              else if (_tab == 1)
                const _TabPlaceholder(
                  icon: CupertinoIcons.chart_bar,
                  title: 'إحصائيات المجموعة',
                  body: 'ستظهر هنا نسبة الحفظ وتوزيع البطاقات بعد تفعيل محرّك المراجعة.',
                )
              else
                const _TabPlaceholder(
                  icon: CupertinoIcons.gear,
                  title: 'إعدادات المجموعة',
                  body: 'يمكنك تعديل الخصوصية، عدد البطاقات اليومية، ونسبة التذكر.',
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: isPreview
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: isSubDeck
                      ? FilledButton.icon(
                          onPressed: () => _addCard(context, deck),
                          icon: const Icon(CupertinoIcons.plus, size: 18),
                          label: const Text('بطاقة جديدة'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _addSubDeck(context, deck),
                          icon: const Icon(
                            CupertinoIcons.folder_badge_plus,
                            size: 18,
                          ),
                          label: const Text('مجموعة فرعية جديدة'),
                        ),
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  List<Widget> _subDeckSection(
    BuildContext context,
    DeckNode deck,
    List<DeckNode> subDecks,
  ) {
    if (subDecks.isEmpty) {
      return <Widget>[
        _EmptyState(
          icon: CupertinoIcons.folder_badge_plus,
          title: 'لا مجموعات فرعية بعد',
          body:
              'المجموعة الرئيسية تنظّم فقط. أنشئ مجموعة فرعية '
              'لتضع فيها البطاقات.',
          actionLabel: 'إنشاء مجموعة فرعية',
          onAction: () => _addSubDeck(context, deck),
        ),
      ];
    }
    return <Widget>[
      SectionHeader(
        title: 'المجموعات الفرعية',
        subtitle: '${subDecks.length} مجموعة · البطاقات داخل كل مجموعة',
        actionLabel: 'إضافة',
        onAction: () => _addSubDeck(context, deck),
      ),
      const SizedBox(height: 10),
      for (final DeckNode child in subDecks)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
          child: DeckCard(
            deck: child,
            onTap: () => context.push('/deck/${child.id}'),
          ),
        ),
    ];
  }

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
              'هذه المجموعة الفرعية جاهزة لبطاقاتك. أضف أول بطاقة '
              'لتظهر في المراجعة.',
          actionLabel: 'إضافة بطاقة',
          onAction: () => _addCard(context, deck),
        ),
      ];
    }
    return <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          onChanged: (String value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'ابحث في البطاقات',
            prefixIcon: const Icon(CupertinoIcons.search, size: 18),
          ),
        ),
      ),
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
          _CardRow(card: visibleCards[index], index: index),
    ];
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _addSubDeck(BuildContext context, DeckNode deck) {
    if (deck.isPreview) {
      _showPreviewNotice(context);
      return;
    }
    if (!deck.canHoldSubDecks) {
      showAppMessage(
        context,
        'لا يمكن إنشاء مجموعة فرعية داخل مجموعة فرعية.',
        kind: AppMessageKind.info,
      );
      return;
    }
    showDeckEditorSheet(context, parentId: deck.id, parentTitle: deck.title);
  }

  void _addCard(BuildContext context, DeckNode deck) {
    if (!deck.canHoldCards) {
      showAppMessage(
        context,
        'البطاقات تُضاف داخل المجموعات الفرعية فقط.',
        kind: AppMessageKind.info,
      );
      return;
    }
    showCardEditorSheet(context, deckId: deck.id);
  }

  void _showActions(BuildContext screenContext, DeckNode deck) {
    final bool canAddSubDeck = deck.canHoldSubDecks;
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
              if (canAddSubDeck)
                ListTile(
                  leading: const Icon(CupertinoIcons.folder_badge_plus),
                  title: const Text('مجموعة فرعية جديدة'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _addSubDeck(screenContext, deck);
                  },
                ),
              ListTile(
                leading: const Icon(CupertinoIcons.pencil),
                title: const Text('تعديل المجموعة'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon(screenContext, 'تعديل المجموعة');
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.square_arrow_up),
                title: const Text('مشاركة ونشر'),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.gear),
                title: const Text('إعدادات المجموعة'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _headerSubtitle(
    DeckNode deck,
    bool isSubDeck,
    int cardTotal,
    bool isPreview,
  ) {
    if (isPreview) {
      return '${deck.cardCount} بطاقة · ${deck.author}';
    }
    if (isSubDeck) {
      return '$cardTotal بطاقة · ${deck.isPublic ? 'عامة' : 'خاصة'}';
    }
    return '${deck.children.length} مجموعات فرعية · ${deck.cardCount} بطاقة';
  }

  String _heroTitle(DeckNode deck, bool isSubDeck, bool isPreview) {
    if (isPreview) {
      return deck.tags.isEmpty ? 'من المكتبة العامة' : deck.tags.join(' · ');
    }
    if (isSubDeck) {
      return deck.tags.isEmpty ? 'مجموعة فرعية' : deck.tags.join(' · ');
    }
    return deck.tags.isEmpty ? 'مجموعة رئيسية' : deck.tags.join(' · ');
  }

  void _showComingSoon(BuildContext context, String feature) {
    showAppMessage(
      context,
      '$feature سيُفعّل في المرحلة القادمة.',
      kind: AppMessageKind.info,
    );
  }

  void _showPreviewNotice(BuildContext context) {
    showAppMessage(
      context,
      'مجموعات المكتبة للمعاينة فقط الآن، وستُفعّل مع الاتصال بالسحابة.',
      kind: AppMessageKind.info,
    );
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

/// Small chip that shows where a sub-deck sits and jumps to its main deck.
class _ParentChip extends StatelessWidget {
  const _ParentChip({required this.parent, required this.onTap});

  final DeckNode parent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                CupertinoIcons.folder,
                size: 13,
                color: context.texts.bodySmall?.color,
              ),
              const SizedBox(width: 6),
              Text(
                'داخل: ${parent.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall,
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_back,
                size: 12,
                color: context.texts.bodySmall?.color,
              ),
            ],
          ),
        ),
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

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.index});

  final ReviewCard card;
  final int index;

  @override
  Widget build(BuildContext context) {
    final List<Color> stateColors = <Color>[
      AppColors.blue,
      AppColors.danger,
      AppColors.primary,
    ];
    final List<String> stateLabels = <String>['جديدة', 'تعلّم', 'راسخة'];
    final int state = card.stateIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colors.outlineVariant,
              width: 0.7,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: stateColors[state],
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(card.front, style: context.texts.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    card.back,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(stateLabels[state], style: context.texts.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: SurfaceCard(
        child: Column(
          children: <Widget>[
            Icon(icon, size: 34, color: context.colors.primary),
            const SizedBox(height: 10),
            Text(title, style: context.texts.titleMedium),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
          ],
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
                        onPressed: () => context.pop(),
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
