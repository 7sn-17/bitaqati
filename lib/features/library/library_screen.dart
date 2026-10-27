import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/deck_card.dart';
import '../../data/library_demo.dart';
import '../../domain/models.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _sort = 0;

  @override
  Widget build(BuildContext context) {
    final String? selected = ref.watch(libraryTagProvider);
    final List<DeckNode> decks = selected == null
        ? kLibraryDecks
        : kLibraryDecks
              .where((DeckNode deck) => deck.hasTag(selected))
              .toList(growable: false);

    return SafeArea(
      bottom: false,
      child: ListView(
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
                        'مجموعات جاهزة من طلاب مثلك',
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.globe, size: 21),
                ),
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
                          'تعلّم من مكتبة الطلاب',
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final LibraryTag subject in kLibraryTags)
                  _SubjectTile(
                    subject: subject,
                    count: subject.count,
                    selected: selected == subject.id,
                    onTap: () {
                      ref.read(libraryTagProvider.notifier).state =
                          selected == subject.id ? null : subject.id;
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    selected == null
                        ? 'الأكثر استخداماً'
                        : selected,
                    style: context.texts.titleLarge,
                  ),
                ),
                _SortButton(
                  label: 'الأكثر استخداماً',
                  selected: _sort == 0,
                  onTap: () => setState(() => _sort = 0),
                ),
                _SortButton(
                  label: 'الأعلى تقييماً',
                  selected: _sort == 1,
                  onTap: () => setState(() => _sort = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final DeckNode deck in decks)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
              child: DeckCard(
                deck: deck,
                showAuthor: true,
                onTap: () => context.push('/deck/${deck.id}'),
                trailing: _AddButton(onTap: () => _addDeck(context, deck)),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'المحتوى من الطلاب · يمكنك الإبلاغ عن أي بطاقة',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _addDeck(BuildContext context, DeckNode deck) {
    showAppMessage(
      context,
      'نسخ «${deck.title}» سيُفعّل عند ربط المكتبة بالسحابة.',
      kind: AppMessageKind.info,
    );
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
                Icon(
                  subject.icon,
                  size: 17,
                  color: selected ? Colors.white : subject.color,
                ),
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
                      color: selected ? Colors.white : subject.color,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '$count مجموعات',
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Colors.white.withValues(alpha: 0.7)
                    : subject.color.withValues(alpha: 0.7),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 30,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(42, 30),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: const Text('أضف'),
      ),
    );
  }
}
