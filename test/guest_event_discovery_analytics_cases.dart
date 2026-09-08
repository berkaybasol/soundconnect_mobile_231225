part of 'guest_event_discovery_screen_test.dart';

void _discoveryAnalyticsTests() {
  testWidgets(
    'actual discovery never records loading error or empty search as an impression',
    (tester) async {
      await _withDiscoveryTracker(tester, (tracker) async {
        final pending = Completer<Result<DiscoveryEventPage>>();
        final search = _Search()..reply = (_) => pending.future;
        await _mount(tester, search: search);
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.impressions, isEmpty);
        await _city(tester, 'Ankara', settle: false);
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.impressions, isEmpty);
        pending.complete(const Result.failure(_failure));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.impressions, isEmpty);
        search.reply = (_) async => _page([]);
        await _location(tester, 'Ankara', 'İstanbul');
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.impressions, isEmpty);
      });
    },
  );

  testWidgets(
    'actual discovery reports the visible card id after dwell not loaded offscreen results',
    (tester) async {
      await _withDiscoveryTracker(tester, (tracker) async {
        final search = _Search()
          ..reply = (_) async =>
              _page(List.generate(20, (index) => 'Konser $index'));
        await _mount(tester, search: search);
        await _city(tester, 'Ankara');
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.impressions, isEmpty);
        await _reveal(
          tester,
          find.byKey(const ValueKey('analytics-impression-Konser 0')),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tracker.impressions, isEmpty);
        await tester.pump(const Duration(seconds: 1));
        expect(tracker.impressions, contains('Konser 0'));
        expect(tracker.impressions, isNot(contains('Konser 19')));
        await tester.pump(const Duration(seconds: 2));
        expect(
          tracker.impressions.where((id) => id == 'Konser 0'),
          hasLength(1),
        );
      });
    },
  );

  testWidgets('actual discovery cancels card dwell when a modal covers it', (
    tester,
  ) async {
    await _withDiscoveryTracker(tester, (tracker) async {
      await _mount(
        tester,
        search: _Search()..reply = (_) async => _page(['Görünür konser']),
      );
      await _city(tester, 'Ankara');
      await _reveal(
        tester,
        find.byKey(const ValueKey('analytics-impression-Görünür konser')),
      );
      final context = tester.element(find.byType(GuestEventDiscoveryScreen));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Örtü')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(tracker.impressions, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(tracker.impressions, ['Görünür konser']);
    });
  });
}

Future<void> _withDiscoveryTracker(
  WidgetTester tester,
  Future<void> Function(_DiscoveryTracker) test,
) async {
  final tracker = _DiscoveryTracker();
  serviceLocator.registerSingleton<AnalyticsTracker>(tracker);
  try {
    await test(tracker);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await serviceLocator.unregister<AnalyticsTracker>();
  }
}

class _DiscoveryTracker extends Fake implements AnalyticsTracker {
  final impressions = <String>[];
  @override
  void recordEventImpression(String eventId) => impressions.add(eventId);
}
