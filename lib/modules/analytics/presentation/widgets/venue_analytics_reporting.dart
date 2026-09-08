import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../domain/venue_analytics_repository.dart';

String analyticsNumber(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

String analyticsDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

enum _Metric {
  reach('Tekil erişim', 'Erişim'),
  detail('Detay ziyaretçisi', 'Detay'),
  profile('Profil ziyaretçisi', 'Profil');

  const _Metric(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
  int read(VenueAnalyticsMetrics metrics) => switch (this) {
    reach => metrics.impressions,
    detail => metrics.detailViews,
    profile => metrics.profileVisits,
  };
}

class VenueAnalyticsDailyChart extends StatefulWidget {
  const VenueAnalyticsDailyChart({super.key, required this.points});
  final List<VenueAnalyticsDailyPoint> points;

  @override
  State<VenueAnalyticsDailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<VenueAnalyticsDailyChart> {
  _Metric _metric = _Metric.reach;
  int? _selected;

  int get _index => (_selected ?? widget.points.length - 1).clamp(
    0,
    math.max(0, widget.points.length - 1),
  );

  @override
  void didUpdateWidget(covariant VenueAnalyticsDailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) _selected = null;
  }

  void _select(int index) {
    if (index >= 0 && index < widget.points.length) {
      setState(() => _selected = index);
    }
  }

  String _description(int index) {
    final point = widget.points[index];
    final value = point.metrics == null
        ? 'Ölçüm yok'
        : '${analyticsNumber(_metric.read(point.metrics!))} ${_metric.label.toLowerCase()}';
    return '${analyticsDate(point.date)}: $value${point.partial ? ', kısmi gün' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final values = points
        .map(
          (point) =>
              point.metrics == null ? null : _metric.read(point.metrics!),
        )
        .toList(growable: false);
    final maximum = values.whereType<int>().fold<int>(0, math.max);
    return AnalyticsReportSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ReportTitle('Günlük görünürlük', Icons.show_chart_rounded),
          const SizedBox(height: 5),
          Text('Her günün tekil ziyaretçileri', style: _muted),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 4,
            children: [
              for (final metric in _Metric.values)
                ChoiceChip(
                  key: Key('analytics-chart-metric-${metric.name}'),
                  label: Text(metric.shortLabel),
                  tooltip: metric.label,
                  selected: _metric == metric,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _metric = metric),
                  selectedColor: AppColors.socialPurple.withValues(alpha: .18),
                  backgroundColor: AppColors.navBlueDeep,
                  side: BorderSide(
                    color: _metric == metric
                        ? AppColors.socialPink
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          if (points.isEmpty) ...[
            const SizedBox(height: 18),
            const Text('Günlük dağılım henüz kullanılamıyor.'),
          ] else ...[
            const SizedBox(height: 18),
            Text(
              values[_index] == null ? '—' : analyticsNumber(values[_index]!),
              key: const Key('analytics-chart-selected-value'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            Text(_metric.label, style: _muted),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${analyticsDate(points[_index].date)}${points[_index].partial ? ' · Kısmi gün' : ''}${points[_index].metrics == null ? ' · Ölçüm yok' : ''}',
                    key: const Key('analytics-chart-selected-date'),
                    style: _muted,
                  ),
                ),
                IconButton(
                  key: const Key('analytics-chart-previous'),
                  tooltip: 'Önceki gün',
                  onPressed: _index > 0 ? () => _select(_index - 1) : null,
                  icon: const BrandGradientIcon.social(
                    Icons.chevron_left_rounded,
                  ),
                ),
                IconButton(
                  key: const Key('analytics-chart-next'),
                  tooltip: 'Sonraki gün',
                  onPressed: _index < points.length - 1
                      ? () => _select(_index + 1)
                      : null,
                  icon: const BrandGradientIcon.social(
                    Icons.chevron_right_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              maximum == 0 ? '0' : analyticsNumber(maximum),
              style: _muted.copyWith(fontSize: 10),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                void selectAt(double x) {
                  final fraction =
                      ((x - 10) / math.max(1, constraints.maxWidth - 20)).clamp(
                        0.0,
                        1.0,
                      );
                  _select((fraction * (points.length - 1)).round());
                }

                return Semantics(
                  key: const Key('analytics-daily-chart-semantics'),
                  label: 'Günlük ${_metric.label.toLowerCase()} grafiği',
                  value: _description(_index),
                  increasedValue: _index < points.length - 1
                      ? _description(_index + 1)
                      : null,
                  decreasedValue: _index > 0 ? _description(_index - 1) : null,
                  onIncrease: _index < points.length - 1
                      ? () => _select(_index + 1)
                      : null,
                  onDecrease: _index > 0 ? () => _select(_index - 1) : null,
                  child: GestureDetector(
                    key: const Key('analytics-daily-chart'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (detail) => selectAt(detail.localPosition.dx),
                    onHorizontalDragUpdate: (detail) =>
                        selectAt(detail.localPosition.dx),
                    child: CustomPaint(
                      size: const Size(double.infinity, 160),
                      painter: _DailyPainter(
                        values: values,
                        partial: points.map((point) => point.partial).toList(),
                        selected: _index,
                        gradient: AppColors.socialGradient,
                        gridColor: AppColors.border,
                        background: AppColors.navBlue,
                      ),
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_shortDate(points.first.date), style: _muted),
                if (points.length > 1)
                  Text(_shortDate(points.last.date), style: _muted),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Grafikte bir güne dokunarak değeri incele. Kısmi gün tamamlanmamış ölçümü, — ölçüm bulunmayan günü gösterir.',
              style: _muted.copyWith(fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Aynı kişi farklı günlerde yeniden sayılabilir. Günlük sayılar dönem toplamı için toplanmaz.',
            style: _muted.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime date) => '${date.day}.${date.month}';
}

class _DailyPainter extends CustomPainter {
  const _DailyPainter({
    required this.values,
    required this.partial,
    required this.selected,
    required this.gradient,
    required this.gridColor,
    required this.background,
  });
  final List<int?> values;
  final List<bool> partial;
  final int selected;
  final List<Color> gradient;
  final Color gridColor;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    const inset = 10.0;
    final baseline = size.height - inset;
    final height = size.height - inset * 2;
    final maximum = math.max(1, values.whereType<int>().fold<int>(0, math.max));
    final grid = Paint()
      ..color = gridColor.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = inset + height * row / 3;
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), grid);
    }
    double xAt(int index) => values.length == 1
        ? size.width / 2
        : inset + (size.width - inset * 2) * index / (values.length - 1);
    Offset point(int index) =>
        Offset(xAt(index), baseline - height * values[index]! / maximum);
    final line = Paint()
      ..shader = LinearGradient(
        colors: gradient,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    var index = 0;
    while (index < values.length) {
      if (values[index] == null) {
        canvas.drawLine(
          Offset(xAt(index) - 2, baseline + 5),
          Offset(xAt(index) + 2, baseline + 5),
          grid,
        );
        index++;
        continue;
      }
      final first = index;
      final path = Path()..moveTo(point(index).dx, point(index).dy);
      while (index + 1 < values.length && values[index + 1] != null) {
        index++;
        path.lineTo(point(index).dx, point(index).dy);
      }
      final fill = Path.from(path)
        ..lineTo(xAt(index), baseline)
        ..lineTo(xAt(first), baseline)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gradient[1].withValues(alpha: .2),
              gradient.last.withValues(alpha: .015),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(path, line);
      for (var dot = first; dot <= index; dot++) {
        if (values.length <= 31 || partial[dot] || first == index) {
          canvas.drawCircle(
            point(dot),
            partial[dot] ? 3.5 : 2.5,
            Paint()..color = partial[dot] ? background : gradient[1],
          );
          if (partial[dot]) {
            canvas.drawCircle(
              point(dot),
              3.5,
              Paint()
                ..color = gradient[1]
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6,
            );
          }
        }
      }
      index++;
    }
    final x = xAt(selected);
    canvas.drawLine(
      Offset(x, inset),
      Offset(x, baseline),
      Paint()
        ..color = gradient.last.withValues(alpha: .6)
        ..strokeWidth = 1,
    );
    if (values[selected] != null) {
      canvas.drawCircle(point(selected), 6, Paint()..color = background);
      canvas.drawCircle(point(selected), 4, Paint()..color = gradient.first);
    }
  }

  @override
  bool shouldRepaint(covariant _DailyPainter oldDelegate) =>
      values != oldDelegate.values ||
      partial != oldDelegate.partial ||
      selected != oldDelegate.selected ||
      gradient != oldDelegate.gradient ||
      gridColor != oldDelegate.gridColor ||
      background != oldDelegate.background;
}

class VenueAnalyticsComparisonCard extends StatelessWidget {
  const VenueAnalyticsComparisonCard({
    super.key,
    required this.comparison,
    required this.days,
  });
  final VenueAnalyticsComparison? comparison;
  final int days;

  @override
  Widget build(BuildContext context) {
    final data = comparison;
    final available =
        data?.status == VenueAnalyticsComparisonStatus.available &&
        data?.currentMetrics != null &&
        data?.previousMetrics != null;
    return AnalyticsReportSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ReportTitle(
            'Dönem karşılaştırması',
            Icons.compare_arrows_rounded,
          ),
          const SizedBox(height: 7),
          Text(
            'Bugün hariç, tamamlanmış iki $days günlük dönem.',
            style: _muted,
          ),
          if (data != null) ...[
            const SizedBox(height: 14),
            Text(
              'Son dönem · ${analyticsDate(data.currentFromDate)} – ${analyticsDate(data.currentToDate)}',
              style: _muted,
            ),
            const SizedBox(height: 4),
            Text(
              'Önceki dönem · ${analyticsDate(data.previousFromDate)} – ${analyticsDate(data.previousToDate)}',
              style: _muted,
            ),
          ],
          const SizedBox(height: 18),
          if (!available)
            Text(
              switch (data?.status) {
                VenueAnalyticsComparisonStatus.notStarted =>
                  'Karşılaştırma için henüz ölçüm kaydı bulunmuyor.',
                VenueAnalyticsComparisonStatus.insufficientHistory =>
                  'İki tam dönemi karşılaştırmak için yeterli ölçüm geçmişi henüz yok.',
                VenueAnalyticsComparisonStatus.retentionLimit =>
                  '90 günlük saklama süresi iki ayrı 90 günlük dönemi karşılamıyor. Karşılaştırma için 7 veya 30 günü seç.',
                _ => 'Dönem karşılaştırması henüz kullanılamıyor.',
              },
              key: const Key('analytics-comparison-unavailable'),
              style: const TextStyle(height: 1.5),
            )
          else
            for (final metric in _Metric.values) ...[
              if (metric != _Metric.reach)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.border),
                ),
              _ComparisonRow(
                label: metric.label,
                current: metric.read(data!.currentMetrics!),
                previous: metric.read(data.previousMetrics!),
                metricKey: metric.name,
              ),
            ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.metricKey,
  });
  final String label;
  final int current;
  final int previous;
  final String metricKey;

  @override
  Widget build(BuildContext context) {
    final difference = current - previous;
    final change = previous == 0
        ? current == 0
              ? 'Değişim yok'
              : 'Önceki dönem 0 · Oran hesaplanamaz'
        : difference == 0
        ? 'Değişim yok'
        : '${difference > 0 ? '+' : '−'}%${(difference.abs() / previous * 100).toStringAsFixed(1).replaceAll('.', ',')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              analyticsNumber(current),
              key: Key('analytics-comparison-$metricKey-current'),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            Text('Önceki: ${analyticsNumber(previous)}', style: _muted),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          change,
          key: Key('analytics-comparison-$metricKey-change'),
          style: TextStyle(
            color: difference == 0 ? AppColors.textMuted : AppColors.socialPink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AnalyticsReportSurface extends StatelessWidget {
  const AnalyticsReportSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.navBlue,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class _ReportTitle extends StatelessWidget {
  const _ReportTitle(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      BrandGradientIcon.social(icon, size: 22),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

TextStyle get _muted =>
    TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted);
