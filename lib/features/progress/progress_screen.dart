import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/surface_card.dart';
import '../../data/models.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _range = 1;

  @override
  Widget build(BuildContext context) {
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
                      Text('تقدّمي', style: context.texts.headlineLarge),
                      const SizedBox(height: 2),
                      Text(
                        'كل مراجعة تقرّبك من الإتقان',
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
                  child: const Icon(
                    CupertinoIcons.chart_bar_fill,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _RangeSelector(
              selected: _range,
              onChanged: (int value) => setState(() => _range = value),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _BigStat(
                    label: 'نسبة الحفظ',
                    value: '91%',
                    dark: true,
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: _BigStat(
                    label: 'أطول سلسلة',
                    value: '21',
                    suffix: 'يوماً',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'نشاط آخر 12 أسبوعاً'),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _Heatmap(),
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'المستحقة خلال 7 أيام',
            subtitle: 'خطّط وقتك قبل أن تتراكم البطاقات',
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _ForecastChart(),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'نسبة الحفظ حسب المادة'),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SubjectRetention(),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: AppColors.warningInk,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '6 بطاقات مزعجة',
                          style: context.texts.titleMedium,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'تنساها مراراً · أعد صياغتها لتصبح أسهل',
                          style: context.texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('عرض'),
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

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>['أسبوع', 'شهر', 'الكل'];
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
                  height: 38,
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
                      fontSize: 13,
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

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    this.suffix,
    this.dark = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color background = dark
        ? AppColors.primary
        : context.colors.surfaceContainerHighest;
    final Color ink = dark ? Colors.white : context.colors.onSurface;
    final Color valueColor = dark ? AppColors.accent : ink;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: dark
                  ? const Color(0xFFCFE8C0)
                  : context.texts.bodySmall?.color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 38,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (suffix != null) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  suffix!,
                  style: TextStyle(
                    fontSize: 11,
                    color: dark
                        ? const Color(0xFFCFE8C0)
                        : context.texts.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap();

  @override
  Widget build(BuildContext context) {
    const int weeks = 12;
    const int days = 7;
    return Column(
      children: <Widget>[
        for (int day = 0; day < days; day++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                for (int week = 0; week < weeks; week++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cellColor(context, week, day),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Color _cellColor(BuildContext context, int week, int day) {
    final int value = (week * 7 + day * 3) % 10;
    if (value < 3) {
      return context.isDark ? AppColors.darkSurface : AppColors.surface;
    }
    if (value < 6) {
      return AppColors.accentSoft;
    }
    if (value < 8) {
      return AppColors.accent;
    }
    return context.isDark ? AppColors.accent : AppColors.primary;
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart();

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'اليوم',
      'غداً',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    const List<double> values = <double>[0.7, 0.42, 0.55, 0.3, 0.62, 0.2, 0.45];

    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${(values[index] * 30).round()}',
                      style: context.texts.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: values[index],
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? context.colors.primary
                                  : AppColors.accent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall,
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

class _SubjectRetention extends StatelessWidget {
  const _SubjectRetention();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final Subject subject in kSubjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 82,
                  child: Text(subject.nameAr, style: context.texts.bodyMedium),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _retention(subject.id) / 100,
                      minHeight: 8,
                      backgroundColor: context.colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${_retention(subject.id).round()}%',
                    textAlign: TextAlign.start,
                    style: context.texts.titleSmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  double _retention(SubjectId id) {
    return switch (id) {
      SubjectId.physics => 88,
      SubjectId.chemistry => 76,
      SubjectId.biology => 91,
      SubjectId.historyOfMedicine => 82,
      SubjectId.english1 => 74,
    };
  }
}
