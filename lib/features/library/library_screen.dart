import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/content_providers.dart';
import '../../data/library_providers.dart';
import '../../data/library_repository.dart';
import '../../data/library_tags.dart';
import '../../domain/models.dart';
import 'install_library_deck.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _installing = <String>{};
  String _query = '';
  int _sort = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Opens the code sheet and jumps to the deck it resolves to.
  Future<void> _enterShareCode() async {
    final TextEditingController controller = TextEditingController();
    final String? code = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('رمز المشاركة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'اطلب من صاحب المجموعة رمزاً من ستة أحرف.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 7,
              ),
              decoration: const InputDecoration(
                hintText: 'ABC123',
                counterText: '',
              ),
              onSubmitted: (String value) =>
                  Navigator.of(dialog).pop(value.trim()),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: const Text('فتح'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !mounted) {
      return;
    }
    final String needle = code.trim().toUpperCase();
    if (needle.length != 6) {
      showAppMessage(
        context,
        'الرمز يتكوّن من ستة أحرف.',
        kind: AppMessageKind.error,
      );
      return;
    }
    try {
      // A code for a deck this account already owns must open that deck, not
      // install a second copy of it.
      final DeckNode? owned = await ref
          .read(contentRepositoryProvider)
          .deckByShareCode(needle);
      if (!mounted) {
        return;
      }
      if (owned != null) {
        context.push('/deck/${owned.id}');
        return;
      }
      final DeckNode? deck = await ref
          .read(libraryRepositoryProvider)
          .resolveShareCode(needle);
      if (!mounted) {
        return;
      }
      if (deck == null) {
        showAppMessage(
          context,
          'لا توجد مجموعة بهذا الرمز. تأكّد منه وحاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
        return;
      }
      final String? localId = ref.read(localDeckIdForSourceProvider(deck.id));
      context.push('/deck/${localId ?? deck.id}');
    } on LibraryFailure catch (error) {
      if (mounted) {
        showAppMessage(context, error.message, kind: AppMessageKind.error);
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'تعذّر البحث عن الرمز. تحقّق من اتصالك وحاول مرة أخرى.',
          kind: AppMessageKind.error,
        );
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(libraryDecksProvider);
    try {
      await ref.read(libraryDecksProvider.future);
    } catch (_) {
      // The error state below explains the failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DeckNode>> catalog = ref.watch(libraryDecksProvider);
    final List<DeckNode> all = catalog.valueOrNull ?? const <DeckNode>[];
    final String? selected = ref.watch(libraryTagProvider);
    final List<LibraryTag> tags = buildLibraryTags(all);
    final List<DeckNode> decks = _visibleDecks(all, selected);
    final List<DeckNode> localDecks =
        ref.watch(deckListProvider).valueOrNull ?? const <DeckNode>[];
    final Map<String, String> installed = <String, String>{};
    for (final DeckNode deck in localDecks) {
      installed.putIfAbsent(deck.id, () => deck.id);
      final String? source = deck.sourceDeckId;
      if (source != null) {
        installed.putIfAbsent(source, () => deck.id);
      }
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: context.colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 118),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'المكتبة العامة',
                          style: context.texts.headlineLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مجموعات جاهزة من متعلّمين حول العالم',
                          style: context.texts.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        _ShareCodeLink(onTap: _enterShareCode),
                      ],
                    ),
                  ),
                  _RefreshButton(busy: catalog.isLoading, onTap: _refresh),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'تعلّم من مكتبة المتعلّمين',
                            style: TextStyle(
                              fontFamily: 'ReadexPro',
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'أضف أي مجموعة إلى مساحتك الخاصة وعدّلها كما تشاء.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      CupertinoIcons.book,
                      color: AppColors.accent,
                      size: 38,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (String value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن مجموعة أو مؤلف أو وسم',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          iconSize: 18,
                        ),
                ),
              ),
            ),
            if (tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final LibraryTag tag in tags)
                      _SubjectTile(
                        subject: tag,
                        count: tag.count,
                        selected: selected == tag.id,
                        onTap: () {
                          ref.read(libraryTagProvider.notifier).state =
                              selected == tag.id ? null : tag.id;
                        },
                      ),
                  ],
                ),
              ),
            ],
            if (all.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        selected ?? 'كل المجموعات',
                        style: context.texts.titleLarge,
                      ),
                    ),
                    Text('${decks.length}', style: context.texts.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    _SortButton(
                      label: 'الأحدث',
                      selected: _sort == 0,
                      onTap: () => setState(() => _sort = 0),
                    ),
                    _SortButton(
                      label: 'الأعلى تقييماً',
                      selected: _sort == 1,
                      onTap: () => setState(() => _sort = 1),
                    ),
                    _SortButton(
                      label: 'الأكثر بطاقات',
                      selected: _sort == 2,
                      onTap: () => setState(() => _sort = 2),
                    ),
                    _SortButton(
                      label: 'الأكثر استخداماً',
                      selected: _sort == 3,
                      onTap: () => setState(() => _sort = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (catalog.isLoading && all.isEmpty)
              const _LibrarySkeleton()
            else if (catalog.hasError && all.isEmpty)
              _LibraryState(
                icon: CupertinoIcons.wifi_exclamationmark,
                title: 'تعذّر تحميل المكتبة',
                body: _errorMessage(catalog.error),
                actionLabel: 'إعادة المحاولة',
                onAction: _refresh,
              )
            else if (all.isEmpty)
              _LibraryState(
                icon: CupertinoIcons.book,
                title: 'لا توجد مجموعات منشورة بعد',
                body:
                    'كن أول من يشارك مجموعة. انشرها من إعدادات المجموعة '
                    'لتظهر هنا.',
                actionLabel: 'تحديث',
                onAction: _refresh,
              )
            else if (decks.isEmpty)
              const _LibraryState(
                icon: CupertinoIcons.search,
                title: 'لا نتائج مطابقة',
                body: 'جرّب وسماً آخر أو كلمة بحث مختلفة.',
              )
            else
              for (final DeckNode deck in decks)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
                  child: DeckCard(
                    deck: deck,
                    showAuthor: true,
                    onTap: () =>
                        context.push('/deck/${installed[deck.id] ?? deck.id}'),
                    trailing: installed.containsKey(deck.id)
                        ? _InstalledButton(
                            onTap: () =>
                                context.push('/deck/${installed[deck.id]}'),
                          )
                        : _AddButton(
                            loading: _installing.contains(deck.id),
                            onTap: () => _addDeck(deck),
                          ),
                  ),
                ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'المحتوى من المتعلّمين · يمكنك الإبلاغ عن أي بطاقة',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DeckNode> _visibleDecks(List<DeckNode> all, String? selected) {
    final String needle = _query.trim().toLowerCase();
    final List<DeckNode> filtered = all.where((DeckNode deck) {
      final bool tagMatches = selected == null || deck.hasTag(selected);
      final bool queryMatches =
          needle.isEmpty ||
          deck.title.toLowerCase().contains(needle) ||
          deck.description.toLowerCase().contains(needle) ||
          (deck.author ?? '').toLowerCase().contains(needle) ||
          deck.tags.any((String tag) => tag.toLowerCase().contains(needle));
      return tagMatches && queryMatches;
    }).toList();
    switch (_sort) {
      case 1:
        filtered.sort(
          (DeckNode a, DeckNode b) => (b.rating ?? 0).compareTo(a.rating ?? 0),
        );
      case 2:
        filtered.sort(
          (DeckNode a, DeckNode b) => b.cardCount.compareTo(a.cardCount),
        );
      case 3:
        filtered.sort(
          (DeckNode a, DeckNode b) => b.installCount.compareTo(a.installCount),
        );
      default:
        break;
    }
    return filtered;
  }

  Future<void> _addDeck(DeckNode deck) async {
    if (_installing.contains(deck.id)) {
      return;
    }
    setState(() => _installing.add(deck.id));
    final String? localId = await installLibraryDeck(context, ref, deck);
    if (!mounted) {
      return;
    }
    setState(() => _installing.remove(deck.id));
    if (localId != null) {
      context.push('/deck/$localId');
    }
  }

  String _errorMessage(Object? error) {
    if (error is LibraryFailure) {
      return error.message;
    }
    return 'تحقّق من اتصالك بالإنترنت وحاول مرة أخرى.';
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final LibraryTag subject;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A subject tile is filled with its own colour when it is selected and
    // tinted with 10% of it when it is not. White type works on the deep
    // tones and disappears on the pastels, so the foreground is derived.
    final Color ink = selected
        ? onDeckColor(subject.color)
        : context.legible(subject.color);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: (MediaQuery.sizeOf(context).width - 50) / 2,
        height: 74,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? subject.color
              : subject.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? subject.color : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(subject.icon, size: 17, color: ink),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    subject.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ReadexPro',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '$count مجموعات',
              style: TextStyle(
                fontSize: 11,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? context.colors.primary
            : context.texts.bodySmall?.color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 34),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.loading = false});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 30,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(52, 30),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : const Text('أضف'),
      ),
    );
  }
}

/// Placeholder for the first frame of the library.
///
/// Four tiles shaped like the real ones keep the layout still while the
/// network answers, instead of a spinner that collapses the whole page and
/// then jumps back to full height.
class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: <Widget>[
            for (int index = 0; index < 4; index++) const DeckTileSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _InstalledButton extends StatelessWidget {
  const _InstalledButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 30,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(58, 30),
          backgroundColor: context.softAccent,
          foregroundColor: context.onSoftAccent,
          textStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(CupertinoIcons.checkmark_alt, size: 12),
            SizedBox(width: 2),
            Text('لديّ'),
          ],
        ),
      ),
    );
  }
}

class _LibraryState extends StatelessWidget {
  const _LibraryState({
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
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 38, color: context.colors.primary),
            const SizedBox(height: 12),
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
                icon: const Icon(CupertinoIcons.refresh, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round action in the library header that pulls the catalog again.
///
/// Replaces the old hashtag button: the share-code entry point moved to a
/// text link under the subtitle, where it reads as an action instead of an
/// unexplained icon.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onTap});

  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'تحديث المكتبة',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  CupertinoIcons.arrow_clockwise,
                  size: 20,
                  color: context.ink,
                ),
        ),
      ),
    );
  }
}

/// The only way into the "I have a code" flow, since the header icon is now
/// refresh.
class _ShareCodeLink extends StatelessWidget {
  const _ShareCodeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              CupertinoIcons.number,
              size: 12,
              color: context.colors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'لديك رمز مشاركة؟',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
