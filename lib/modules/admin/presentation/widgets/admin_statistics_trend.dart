import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Missing days stay visibly disconnected from recorded zero days.
class AdminStatisticsTrend extends StatelessWidget {
  const AdminStatisticsTrend({
    super.key,
    required this.days,
    required this.average,
    required this.format,
  });

  final Map<DateTime, int?> days;
  final String average;
  final String Function(num value) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = days.keys.toList()..sort();
    final values = dates.map((day) => days[day]).toList();
    final measured = values.nonNulls.toList();
    final high = measured.isEmpty ? null : measured.reduce(math.max);
    final caption = high == null
        ? 'Günlük ölçüm bulunmuyor.'
        : 'En yüksek ${format(high)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Günlük aktif üyeler',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text('$average ort.', style: theme.textTheme.titleSmall),
          ],
        ),
        Text('GA4 · günlük tekil hesap', style: theme.textTheme.bodySmall),
        if (high != null) ...[
          Semantics(
            label:
                'Günlük aktif üyeler, ortalama $average, en yüksek ${format(high)}.',
            child: SizedBox(
              height: 58,
              child: CustomPaint(
                painter: _ChartPainter(
                  values,
                  theme.colorScheme.brightness == Brightness.dark
                      ? const Color(0xffc4adff)
                      : const Color(0xff7054a0),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${dates.first.day}.${dates.first.month}',
                style: theme.textTheme.labelSmall,
              ),
              Text(caption, style: theme.textTheme.labelSmall),
              Text(
                '${dates.last.day}.${dates.last.month}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(caption, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.color);
  final List<int?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maximum = values.nonNulls.fold(1, math.max);
    final baseline = size.height - 4;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = color.withValues(alpha: .25),
    );
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .32), color.withValues(alpha: .015)],
      ).createShader(Offset.zero & size);
    final series = <Offset>[];
    void drawSeries() {
      if (series.isEmpty) return;
      if (series.length == 1) {
        canvas.drawCircle(series.first, 2, Paint()..color = color);
      } else {
        final line = Path()..addPolygon(series, false);
        final area = Path.from(line)
          ..lineTo(series.last.dx, baseline)
          ..lineTo(series.first.dx, baseline)
          ..close();
        canvas.drawPath(area, fill);
        canvas.drawPath(line, stroke);
      }
      series.clear();
    }

    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        drawSeries();
      } else {
        series.add(
          Offset(
            size.width * index / math.max(1, values.length - 1),
            baseline - (baseline - 4) * value / maximum,
          ),
        );
      }
    }
    drawSeries();
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
