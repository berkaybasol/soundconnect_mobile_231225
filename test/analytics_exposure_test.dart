import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_exposure.dart';

Widget _app(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [analyticsRouteObserver],
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

Widget _card(
  VoidCallback exposed, {
  bool enabled = true,
  Duration? duration,
  Key? key,
}) => AnalyticsExposure(
  key: key,
  enabled: enabled,
  minimumVisibleDuration: duration ?? const Duration(seconds: 1),
  onExposed: exposed,
  child: const SizedBox(
    width: 200,
    height: 100,
    child: ColoredBox(color: Colors.red),
  ),
);

void main() {
  testWidgets(
    'does not record on construction and requires one full visible second',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(_app(_card(() => count++)));
      expect(count, 0);
      await tester.pump(const Duration(milliseconds: 999));
      expect(count, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(count, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(count, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'verified page zero dwell still waits for actual painted visibility',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _app(_card(() => count++, duration: Duration.zero)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(count, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final visibleWidth in [98.0, 100.0]) {
    testWidgets('counts only at least fifty percent: $visibleWidth / 200', (
      tester,
    ) async {
      var count = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: visibleWidth,
            height: 100,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 200,
                maxWidth: 200,
                minHeight: 100,
                maxHeight: 100,
                child: _card(() => count++),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(count, visibleWidth == 100 ? 1 : 0);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'verified data enabling after settle records on the next event turn',
    (tester) async {
      var count = 0;
      final verified = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: verified,
            builder: (_, enabled, _) =>
                _card(() => count++, enabled: enabled, duration: Duration.zero),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(count, 0);
      verified.value = true;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      expect(count, 1);
      await tester.pumpWidget(const SizedBox());
      verified.dispose();
    },
  );

  testWidgets('horizontal and vertical viewport clips are intersected', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 100,
          height: 50,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 200,
              maxWidth: 200,
              minHeight: 100,
              maxHeight: 100,
              child: _card(() => count++),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(count, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'built offscreen content is not an impression until scrolled into view',
    (tester) async {
      var count = 0;
      final controller = ScrollController();
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [const SizedBox(height: 800), _card(() => count++)],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(count, 0);
      controller.jumpTo(300);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(count, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('modal route cancels dwell and returning starts a fresh second', (
    tester,
  ) async {
    var count = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(_card(() => count++), navigatorKey: navigator),
    );
    await tester.pump(const Duration(milliseconds: 400));
    navigator.currentState!.push(
      RawDialogRoute<void>(
        pageBuilder: (_, _, _) => const Center(child: Text('Dialog')),
        transitionDuration: Duration.zero,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(count, 0);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(count, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background time cannot complete or continue a dwell', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(_app(_card(() => count++)));
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(count, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 999));
    expect(count, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offstage and disabled operational cards do not count', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Offstage(offstage: true, child: _card(() => count++)),
            _card(() => count++, enabled: false),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(count, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('zero opacity cancels dwell even when geometry is unchanged', (
    tester,
  ) async {
    var count = 0;
    final opacity = ValueNotifier<double>(1);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<double>(
          valueListenable: opacity,
          builder: (_, value, child) => Opacity(opacity: value, child: child),
          child: _card(() => count++),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    opacity.value = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(count, 0);
    opacity.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(count, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
    opacity.dispose();
  });

  testWidgets('a brief clipping dip resets the continuous exposure window', (
    tester,
  ) async {
    var count = 0;
    final width = ValueNotifier<double>(100);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<double>(
          valueListenable: width,
          builder: (_, value, child) => SizedBox(
            width: value,
            height: 100,
            child: ClipRect(
              child: OverflowBox(
                minWidth: 200,
                maxWidth: 200,
                minHeight: 100,
                maxHeight: 100,
                alignment: Alignment.topLeft,
                child: child,
              ),
            ),
          ),
          child: _card(() => count++),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    width.value = 98;
    await tester.pump();
    width.value = 100;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    expect(count, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
    width.dispose();
  });

  testWidgets(
    'disposed cards never invoke callbacks and leave no dwell timer',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(_app(_card(() => count++)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(count, 0);
    },
  );

  testWidgets('callbacks cannot break the page when instrumentation fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_card(() => throw StateError('instrumentation failure'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
