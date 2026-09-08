import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/venue_analytics_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/venue_analytics_reporting.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'chart selects date by touch and switches metric without a request',
    (tester) async {
      await _mount(tester, VenueAnalyticsDailyChart(points: _points()));
      expect(_selected(tester), '214');
      expect(find.text('08.09.2026 · Kısmi gün'), findsOneWidget);
      final plot = find.byKey(const Key('analytics-daily-chart'));
      await tester.tapAt(tester.getTopLeft(plot) + const Offset(10, 60));
      await tester.pump();
      expect(_selected(tester), '74');
      expect(find.text('02.09.2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('analytics-chart-metric-detail')));
      await tester.pump();
      expect(_selected(tester), '18');
      await tester.tap(find.byKey(const Key('analytics-chart-next')));
      await tester.pump();
      expect(find.text('03.09.2026'), findsOneWidget);
    },
  );

  testWidgets(
    'chart distinguishes unknown data, real zero, and partial observations',
    (tester) async {
      final points = [
        VenueAnalyticsDailyPoint(
          date: DateTime.utc(2026, 9, 6),
          metrics: null,
          partial: false,
        ),
        VenueAnalyticsDailyPoint(
          date: DateTime.utc(2026, 9, 7),
          metrics: _metrics(0),
          partial: false,
        ),
        VenueAnalyticsDailyPoint(
          date: DateTime.utc(2026, 9, 8),
          metrics: _metrics(5),
          partial: true,
        ),
      ];
      await _mount(tester, VenueAnalyticsDailyChart(points: points));
      await tester.tap(find.byKey(const Key('analytics-chart-previous')));
      await tester.pump();
      expect(_selected(tester), '0');
      await tester.tap(find.byKey(const Key('analytics-chart-previous')));
      await tester.pump();
      expect(_selected(tester), '—');
      expect(find.text('06.09.2026 · Ölçüm yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final values in <List<int?>>[
    [],
    [0],
    [null],
    [9],
    [0, 0, 0],
  ]) {
    testWidgets('chart safely renders edge case $values', (tester) async {
      await _mount(
        tester,
        VenueAnalyticsDailyChart(
          points: [
            for (var index = 0; index < values.length; index++)
              VenueAnalyticsDailyPoint(
                date: DateTime.utc(2026, 9, index + 1),
                metrics: values[index] == null
                    ? null
                    : _metrics(values[index]!),
                partial: index == values.length - 1,
              ),
          ],
        ),
      );
      if (values.isEmpty) {
        expect(
          find.text('Günlük dağılım henüz kullanılamıyor.'),
          findsOneWidget,
        );
      } else {
        await tester.tap(find.byKey(const Key('analytics-daily-chart')));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'chart exposes a date/value semantic slider with day navigation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester, VenueAnalyticsDailyChart(points: _points()));
        final target = find.byKey(const Key('analytics-daily-chart-semantics'));
        final data = tester.getSemantics(target).getSemanticsData();
        expect(data.value, '08.09.2026: 214 tekil erişim, kısmi gün');
        expect(data.hasAction(ui.SemanticsAction.decrease), isTrue);
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          tester.getSemantics(target).id,
          ui.SemanticsAction.decrease,
        );
        await tester.pump();
        expect(find.text('07.09.2026'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'comparison uses its own completed ranges and handles zero denominator',
    (tester) async {
      await _mount(
        tester,
        VenueAnalyticsComparisonCard(
          comparison: _comparison(current: 50, previous: 0),
          days: 7,
        ),
      );
      expect(
        find.text('Bugün hariç, tamamlanmış iki 7 günlük dönem.'),
        findsOneWidget,
      );
      expect(find.text('Son dönem · 01.09.2026 – 07.09.2026'), findsOneWidget);
      expect(
        find.text('Önceki dönem · 25.08.2026 – 31.08.2026'),
        findsOneWidget,
      );
      expect(find.text('Önceki dönem 0 · Oran hesaplanamaz'), findsNWidgets(3));
      expect(find.textContaining('Infinity'), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final pair in [
    (0, 0, 'Değişim yok'),
    (50, 100, '−%50,0'),
    (150, 100, '+%50,0'),
  ]) {
    testWidgets('comparison renders honest change ${pair.$3}', (tester) async {
      await _mount(
        tester,
        VenueAnalyticsComparisonCard(
          comparison: _comparison(current: pair.$1, previous: pair.$2),
          days: 7,
        ),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('analytics-comparison-reach-change')),
            )
            .data,
        pair.$3,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in VenueAnalyticsComparisonStatus.values.where(
    (value) => value != VenueAnalyticsComparisonStatus.available,
  )) {
    testWidgets(
      'comparison unavailable ${status.name} never fabricates metrics',
      (tester) async {
        await _mount(
          tester,
          VenueAnalyticsComparisonCard(
            comparison: _comparison(status: status),
            days: 7,
          ),
        );
        expect(
          find.byKey(const Key('analytics-comparison-unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('analytics-comparison-reach-current')),
          findsNothing,
        );
      },
    );
  }

  testWidgets('reporting supports 320 px 200 percent text and huge counts', (
    tester,
  ) async {
    await _mount(
      tester,
      Column(
        children: [
          VenueAnalyticsDailyChart(points: _points()),
          const SizedBox(height: 16),
          VenueAnalyticsComparisonCard(
            comparison: _comparison(current: 999999999999),
            days: 7,
          ),
        ],
      ),
      size: const Size(320, 720),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  final render = Platform.environment['VENUE_ANALYTICS_RENDER_DIR'];
  if (render != null) {
    testWidgets('render premium reporting states', (tester) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final font in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          loader.addFont(
            File('$fonts/$font').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final samples = <String, Widget>{
        'daily-chart': VenueAnalyticsDailyChart(points: _points()),
        'period-comparison': VenueAnalyticsComparisonCard(
          comparison: _comparison(current: 1840, previous: 1260),
          days: 7,
        ),
        'no-history': VenueAnalyticsDailyChart(
          points: [
            for (var i = 0; i < 7; i++)
              VenueAnalyticsDailyPoint(
                date: DateTime.utc(2026, 9, i + 2),
                metrics: i == 6 ? _metrics(12) : null,
                partial: i == 6,
              ),
          ],
        ),
      };
      for (final entry in samples.entries) {
        await tester.pumpWidget(const SizedBox.shrink());
        final capture = GlobalKey();
        await _mount(tester, entry.value, capture: capture);
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(render).create(recursive: true);
          await File(
            '$render/${entry.key}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}

String? _selected(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('analytics-chart-selected-value')))
    .data;

VenueAnalyticsMetrics _metrics(int value) => VenueAnalyticsMetrics(
  impressions: value,
  detailViews: value,
  profileVisits: value,
);

List<VenueAnalyticsDailyPoint> _points() => [
  for (var index = 0; index < 7; index++)
    VenueAnalyticsDailyPoint(
      date: DateTime.utc(2026, 9, index + 2),
      metrics: VenueAnalyticsMetrics(
        impressions: [74, 112, 98, 176, 136, 252, 214][index],
        detailViews: 18 + index * 5,
        profileVisits: 4 + index * 2,
      ),
      partial: index == 6,
    ),
];

VenueAnalyticsComparison _comparison({
  int current = 200,
  int previous = 100,
  VenueAnalyticsComparisonStatus status =
      VenueAnalyticsComparisonStatus.available,
}) => VenueAnalyticsComparison(
  status: status,
  currentFromDate: DateTime.utc(2026, 9, 1),
  currentToDate: DateTime.utc(2026, 9, 7),
  previousFromDate: DateTime.utc(2026, 8, 25),
  previousToDate: DateTime.utc(2026, 8, 31),
  currentMetrics: status == VenueAnalyticsComparisonStatus.available
      ? _metrics(current)
      : null,
  previousMetrics: status == VenueAnalyticsComparisonStatus.available
      ? _metrics(previous)
      : null,
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double scale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: capture == null
            ? AppTheme.navy
            : AppTheme.navy.copyWith(
                textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
                primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                  fontFamily: 'Roboto',
                ),
              ),
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: widget!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('İstatistikler'), centerTitle: true),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
