import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../i18n/app_strings.dart';
import '../theme/app_theme.dart';

class ReviewHeatmap extends StatelessWidget {
  const ReviewHeatmap({required this.days, super.key});

  final List<DailyCount> days;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final int max = days.fold<int>(
      1,
      (int value, DailyCount day) => math.max(value, day.count),
    );
    final List<DailyCount> visible = days.length > 84
        ? days.sublist(days.length - 84)
        : days;
    final List<List<DailyCount>> weeks = <List<DailyCount>>[];
    for (int i = 0; i < visible.length; i += 7) {
      final int end = math.min(i + 7, visible.length);
      weeks.add(visible.sublist(i, end));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: context.isArabic,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weeks
                .map(
                  (List<DailyCount> week) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      children: List<Widget>.generate(7, (int index) {
                        if (index >= week.length) {
                          return const SizedBox(width: 13, height: 13);
                        }
                        final DailyCount day = week[index];
                        final double intensity = day.count == 0
                            ? 0
                            : (0.18 + (day.count / max) * 0.82);
                        return Tooltip(
                          message:
                              '${context.strings.shortDate(day.date)} · ${day.count}',
                          child: Container(
                            width: 13,
                            height: 13,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: day.count == 0
                                  ? colors.surfaceContainerHighest
                                  : Color.lerp(
                                      colors.primary.withValues(alpha: 0.28),
                                      colors.primary,
                                      intensity,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: <Widget>[
            Text(context.strings.activity, style: context.texts.labelSmall),
            const Spacer(),
            Text('0', style: context.texts.labelSmall),
            const SizedBox(width: 4),
            ...List<Widget>.generate(4, (int index) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.18 + index * 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
            const SizedBox(width: 4),
            Text('$max', style: context.texts.labelSmall),
          ],
        ),
      ],
    );
  }
}

class ForecastChart extends StatelessWidget {
  const ForecastChart({required this.days, super.key});

  final List<DailyCount> days;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      width: double.infinity,
      child: CustomPaint(
        painter: _ForecastPainter(
          days: days,
          barColor: context.colors.primary,
          trackColor: context.colors.surfaceContainerHighest,
          labelColor: context.colors.onSurfaceVariant,
          highlightColor: context.colors.secondary,
        ),
      ),
    );
  }
}

class _ForecastPainter extends CustomPainter {
  const _ForecastPainter({
    required this.days,
    required this.barColor,
    required this.trackColor,
    required this.labelColor,
    required this.highlightColor,
  });

  final List<DailyCount> days;
  final Color barColor;
  final Color trackColor;
  final Color labelColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) {
      return;
    }
    const double labelHeight = 22;
    const double topPadding = 8;
    final double chartHeight = size.height - labelHeight - topPadding;
    final int max = days.fold<int>(
      1,
      (int value, DailyCount day) => math.max(value, day.count),
    );
    final double slot = size.width / days.length;
    final double barWidth = math.max(3, slot - 4);
    final Paint track = Paint()..color = trackColor;
    final Paint bar = Paint()..color = barColor;
    final Paint highlight = Paint()..color = highlightColor;
    for (int i = 0; i < days.length; i += 1) {
      final DailyCount day = days[i];
      final double x = i * slot + (slot - barWidth) / 2;
      final RRect trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, topPadding, barWidth, chartHeight),
        const Radius.circular(5),
      );
      canvas.drawRRect(trackRect, track);
      final double ratio = day.count == 0 ? 0 : day.count / max;
      final double height = math.max(
        day.count == 0 ? 0 : 5,
        chartHeight * ratio,
      );
      if (height > 0) {
        final RRect barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topPadding + chartHeight - height, barWidth, height),
          const Radius.circular(5),
        );
        canvas.drawRRect(barRect, i == 0 || i == 1 ? highlight : bar);
      }
      if (i % 5 == 0) {
        final TextPainter painter = TextPainter(
          text: TextSpan(
            text: '${day.date.day}',
            style: TextStyle(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(x + barWidth / 2 - painter.width / 2, size.height - 15),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.barColor != barColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class MiniBars extends StatelessWidget {
  const MiniBars({required this.values, super.key, this.color});

  final List<int> values;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final int max = values.fold<int>(
      1,
      (int value, int next) => math.max(value, next),
    );
    final Color accent = color ?? context.colors.primary;
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values
            .map(
              (int value) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: value == 0 ? 3 : 7 + (value / max) * 27,
                    decoration: BoxDecoration(
                      color: value == 0
                          ? context.colors.surfaceContainerHighest
                          : accent.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
