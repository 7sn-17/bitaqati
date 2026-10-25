import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/models.dart';

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({required this.deckId, super.key});

  final String deckId;

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final DeckSummary deck = findDeck(widget.deckId);
    final List<ReviewCard> cards = cardsForDeck(deck);

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
                          '${deck.cardCount} بطاقة · ${deck.isPublic ? 'عامة' : 'خاصة'}',
                          style: context.texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: CupertinoIcons.ellipsis,
                    label: 'المزيد',
                    onTap: () => _showActions(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      deck.subject.color,
                      deck.subject.color.withValues(alpha: 0.82),
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
                      child: Icon(
                        deck.subject.icon,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            deck.subject.nameAr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deck.retention > 0
                                ? 'نسبة الحفظ ${deck.retention.round()}% · ${deck.dueCount} مستحقة'
                                : '${deck.cardCount} بطاقة · ${deck.author ?? 'مجهول'}',
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
                      value: '8',
                      label: 'جديدة',
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      value: '3',
                      label: 'تعلّم',
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      value: '13',
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
                  onPressed: () => context.push('/review/${deck.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: deck.isPublic
                        ? AppColors.primary
                        : AppColors.accent,
                    foregroundColor: deck.isPublic
                        ? AppColors.accent
                        : AppColors.primary,
                  ),
                  child: Text(
                    deck.isPublic
                        ? 'أضف نسخة إلى مجموعاتي'
                        : 'ادرس هذه المجموعة',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Tabs(
                selected: _tab,
                onChanged: (int value) => setState(() => _tab = value),
              ),
            ),
            const SizedBox(height: 14),
            if (_tab == 0) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث في البطاقات',
                    prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    'لا توجد بطاقات بعد.',
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall,
                  ),
                )
              else
                for (int index = 0; index < cards.length; index++)
                  _CardRow(card: cards[index], index: index),
            ] else if (_tab == 1)
              const _TabPlaceholder(
                icon: CupertinoIcons.chart_bar,
                title: 'إحصائيات المجموعة',
                body: 'ستظهر هنا نسبة الحفظ وتوزيع البطاقات بعد تفعيل محرّك المراجعة.',
              )
            else
              const _TabPlaceholder(
                icon: CupertinoIcons.gear,
                title: 'إعدادات المجموعة',
                body:
                    'يمكنك تعديل الخصوصية، عدد البطاقات اليومية، ونسبة التذكر.',
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showComingSoon(context, 'إضافة بطاقة'),
                  icon: const Icon(CupertinoIcons.plus, size: 18),
                  label: const Text('بطاقة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context, 'استيراد البطاقات'),
                  icon: const Icon(CupertinoIcons.square_arrow_down, size: 18),
                  label: const Text('استيراد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
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
                onTap: () => Navigator.of(context).pop(),
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

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature سيُفعّل في المرحلة القادمة.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>['البطاقات', 'إحصائيات', 'الإعدادات'];
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
    final int state = index % 3;
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
