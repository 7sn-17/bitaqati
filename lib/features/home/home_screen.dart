import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_display.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/tag_filter_bar.dart';
import '../../data/content_providers.dart';
import '../../data/profile_providers.dart';
import '../../domain/models.dart';
import '../study/study_mode_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _consumePendingLink();
    });
  }

  Future<void> _consumePendingLink() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final String? deckId = prefs.getString(AppConfig.pendingDeckKey);
    if (deckId == null || deckId.isEmpty) {
      return;
    }
    await prefs.remove(AppConfig.pendingDeckKey);
    if (!mounted) {
      return;
    }
    context.push('/deck/$deckId');
  }

  @override
  Widget build(BuildContext context) {
    final String? selected = ref.watch(selectedTagProvider);
    final List<DeckNode> allDecks = ref.watch(allDecksProvider);
    final List<DeckNode> decks = selected == null
        ? allDecks
        : allDecks
              .where((DeckNode deck) => deck.hasTag(selected))
              .toList(growable: false);
    final int totalCards = allDecks.fold<int>(
      0,
      (int sum, DeckNode deck) => sum + deck.cardCount,
    );
    final DueTotals due = ref.watch(dueTotalsProvider);
    final int streak = ref.watch(streakProvider).valueOrNull ?? 0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 118),
        children: <Widget>[
          _HomeHeader(onSearch: () => context.push('/search')),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DailyReviewHero(
              due: due,
              streak: streak,
              totalCards: totalCards,
            ),
          ),
          const SizedBox(height: 20),
          TagFilterBar(
            tags: ref.watch(deckTagsProvider),
            selected: selected,
            onChanged: (String? value) {
              ref.read(selectedTagProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'مجموعاتي',
            subtitle: '${allDecks.length} مجموعات · $totalCards بطاقة',
            actionLabel: 'عرض الكل',
            onAction: () => context.go('/decks'),
          ),
          const SizedBox(height: 10),
          if (decks.isEmpty)
            const _NoDecks()
          else
            for (final DeckNode deck in decks)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
                child: DeckCard(
                  deck: deck,
                  onTap: () => context.push('/deck/${deck.id}'),
                ),
              ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LibraryBanner(onTap: () => context.go('/library')),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(currentUserProvider).valueOrNull;
    final bool guestMode = ref.watch(guestModeProvider);
    final bool guest = user == null && guestMode;

    final int hour = DateTime.now().hour;
    final String timeGreeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';
    // A name chosen in Settings wins over the Google name here too.
    final String displayName = ref.watch(displayNameProvider);
    final String greeting = user == null
        ? (guest ? 'أهلاً بك، تابع كزائر' : 'أهلاً بك')
        : '$timeGreeting، $displayName';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _HeaderAvatar(
                url: userAvatarUrl(user),
                initial: displayName.isEmpty
                    ? userInitial(user)
                    : displayName.substring(0, 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall,
                ),
                Text(
                  'بطاقاتي',
                  style: context.texts.headlineMedium?.copyWith(
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(
            icon: CupertinoIcons.search,
            label: 'بحث',
            onTap: onSearch,
          ),
        ],
      ),
    );
  }
}

/// Google profile photo with a letter fallback, sized for the header.
class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.url, required this.initial});

  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(
      initial,
      style: TextStyle(
        fontFamily: 'ReadexPro',
        color: context.accent,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    );
    if (url == null) {
      return label;
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: 46,
      height: 46,
      fit: BoxFit.cover,
      memCacheWidth: 138,
      maxWidthDiskCache: 138,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (BuildContext context, String url, Object error) => label,
    );
  }
}

class _DailyReviewHero extends StatelessWidget {
  const _DailyReviewHero({
    required this.due,
    required this.streak,
    required this.totalCards,
  });

  final DueTotals due;
  final int streak;

  /// Every card in the library. The hero studies the whole library, so the
  /// sheet it opens needs the library's size, not one deck's.
  final int totalCards;

  @override
  Widget build(BuildContext context) {
    final int minutes = (due.total * 22 / 60).ceil();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'مراجعة اليوم',
                  style: TextStyle(
                    color: context.accentSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.primaryDeep,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(CupertinoIcons.flame, color: context.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      streak == 0 ? 'ابدأ سلسلتك' : '$streak يوماً',
                      style: TextStyle(
                        color: context.accent.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${due.total}',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  color: context.accent,
                  fontSize: 60,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                due.total == 0 ? 'لا بطاقات مستحقة' : 'بطاقة · $minutes دقائق',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: due.total == 0
                  ? ColoredBox(color: context.primaryDeep)
                  : Row(
                      children: <Widget>[
                        if (due.fresh > 0)
                          Expanded(
                            flex: due.fresh,
                            child: ColoredBox(color: context.accent),
                          ),
                        if (due.fresh > 0 && due.learning + due.review > 0)
                          const SizedBox(width: 3),
                        if (due.learning > 0)
                          Expanded(
                            flex: due.learning,
                            child: ColoredBox(color: context.accentSoft),
                          ),
                        if (due.learning > 0 && due.review > 0)
                          const SizedBox(width: 3),
                        if (due.review > 0)
                          Expanded(
                            flex: due.review,
                            child: ColoredBox(color: context.primaryDeep),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LegendDot(color: context.accent, label: 'جديدة ${due.fresh}'),
              const SizedBox(width: 14),
              _LegendDot(
                color: context.accentSoft,
                label: 'تعلّم ${due.learning}',
              ),
              const SizedBox(width: 14),
              _LegendDot(
                color: context.primaryDeep,
                label: 'مراجعة ${due.review}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: due.total == 0
                  ? null
                  : () => openGlobalStudy(
                      context,
                      cardCount: totalCards,
                      dueCount: due.total,
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.onAccent,
                disabledBackgroundColor: context.accent.withValues(alpha: 0.3),
                disabledForegroundColor: context.onPrimary.withValues(
                  alpha: 0.45,
                ),
              ),
              child: Text(
                due.total == 0
                    ? 'لا توجد بطاقات مستحقة'
                    : 'مراجعة جميع البطاقات المستحقة',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: context.accentSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LibraryBanner extends StatelessWidget {
  const _LibraryBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The brand green is a hole in a dark banner, so in dark mode the pair
    // flips: a lime mark with green ink on it, which is the same contrast
    // the light theme gets from green on lime.
    final bool dark = context.isDark;
    final Color background = dark ? context.raisedSurface : context.accentSoft;
    final Color markFill = dark ? context.accent : context.primary;
    final Color markInk = dark ? context.primary : context.accent;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: markFill, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.book, color: markInk, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('اكتشف مجموعات الطلاب', style: context.texts.titleMedium),
                const SizedBox(height: 1),
                Text(
                  'بطاقات جاهزة لكل مادة، أضفها بضغطة',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: markFill,
              foregroundColor: markInk,
              textStyle: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('المكتبة'),
          ),
        ],
      ),
    );
  }
}

class _NoDecks extends StatelessWidget {
  const _NoDecks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const EmptyState(
          icon: CupertinoIcons.rectangle_stack,
          title: 'لا توجد مجموعات هنا بعد',
          message:
              'أنشئ مجموعتك الأولى من زر + في الأسفل، أو ثبّت مجموعة '
              'جاهزة من المكتبة.',
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
