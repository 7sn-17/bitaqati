import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/deck_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/subject_chip.dart';
import '../../data/models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubjectId? selected = ref.watch(selectedSubjectProvider);
    final List<DeckSummary> decks = selected == null
        ? kMyDecks
        : kMyDecks
              .where((DeckSummary deck) => deck.subjectId == selected)
              .toList(growable: false);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 118),
        children: <Widget>[
          _HomeHeader(onSearch: () => context.push('/search')),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _DailyReviewHero(),
          ),
          const SizedBox(height: 20),
          SubjectFilterBar(
            selected: selected,
            onChanged: (SubjectId? value) {
              ref.read(selectedSubjectProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'مجموعاتي',
            subtitle: '${kMyDecks.length} مجموعات · 398 بطاقة',
            actionLabel: 'عرض الكل',
            onAction: () => context.go('/decks'),
          ),
          const SizedBox(height: 10),
          if (decks.isEmpty)
            const _NoDecks()
          else
            for (final DeckSummary deck in decks)
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final int hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? 'صباح الخير'
        : hour < 17
        ? 'مساء الخير'
        : 'مساء الخير';

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
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'ب',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  color: AppColors.accent,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(greeting, style: context.texts.bodySmall),
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

class _DailyReviewHero extends StatelessWidget {
  const _DailyReviewHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'مراجعة اليوم',
                  style: TextStyle(
                    color: Color(0xFFCFE8C0),
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
                  color: const Color(0xFF054D28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      CupertinoIcons.flame,
                      color: AppColors.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '12 يوماً',
                      style: TextStyle(
                        color: AppColors.accent.withValues(alpha: 0.95),
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
              const Text(
                '24',
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  color: AppColors.accent,
                  fontSize: 60,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'بطاقة · 9 دقائق',
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
            child: const SizedBox(
              height: 8,
              child: Row(
                children: <Widget>[
                  Expanded(flex: 8, child: ColoredBox(color: AppColors.accent)),
                  SizedBox(width: 3),
                  Expanded(
                    flex: 3,
                    child: ColoredBox(color: Color(0xFFE2F6D5)),
                  ),
                  SizedBox(width: 3),
                  Expanded(
                    flex: 13,
                    child: ColoredBox(color: Color(0xFF054D28)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: <Widget>[
              _LegendDot(color: AppColors.accent, label: 'جديدة 8'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFFE2F6D5), label: 'تعلّم 3'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFF054D28), label: 'مراجعة 13'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/review/biology-cell'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('ابدأ المراجعة'),
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
          style: const TextStyle(
            color: Color(0xFFCFE8C0),
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
    final Color background = context.isDark
        ? AppColors.darkSurfaceHigh
        : AppColors.accentSoft;
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
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.book,
              color: AppColors.accent,
              size: 22,
            ),
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              CupertinoIcons.rectangle_stack,
              size: 36,
              color: context.texts.bodySmall?.color,
            ),
            const SizedBox(height: 10),
            Text(
              'لا توجد مجموعات في هذه المادة بعد',
              textAlign: TextAlign.center,
              style: context.texts.titleMedium,
            ),
            const SizedBox(height: 3),
            Text(
              'أنشئ مجموعة جديدة من زر + في الأسفل.',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
          ],
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
