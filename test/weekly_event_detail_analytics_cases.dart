part of 'weekly_event_detail_design_test.dart';

void _detailAnalyticsTests(
  _DetailRepository Function() details,
  _VenueRepository Function() venues,
) {
  group('real event detail analytics integration', () {
    late _DetailAnalyticsTracker tracker;
    late _DetailAnalyticsRepository analytics;

    setUp(() {
      tracker = _DetailAnalyticsTracker();
      analytics = _DetailAnalyticsRepository();
      venues().includePhoto = false;
      serviceLocator
        ..registerSingleton<AnalyticsTracker>(tracker)
        ..registerSingleton<VenueAnalyticsRepository>(analytics);
    });

    testWidgets('summary render is not a view until public detail verifies', (
      tester,
    ) async {
      details().completion = Completer<Result<VenueEventDetail>>();
      await _openDetail(tester, _event(venueId: 'venue-analytics'));
      expect(tracker.details, isEmpty);
      details().completion!.complete(Result.success(_analyticsDetail()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      expect(tracker.details, ['event-design-1']);
      expect(analytics.reads, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(tracker.details, hasLength(1));
    });

    for (final mismatch in ['event', 'venue', 'failed']) {
      testWidgets('$mismatch public detail cannot create a measurement', (
        tester,
      ) async {
        details().result = mismatch == 'failed'
            ? const Result.failure(AppError(code: '404', message: 'Missing'))
            : Result.success(
                _analyticsDetail(
                  eventId: mismatch == 'event'
                      ? 'another-event'
                      : 'event-design-1',
                  venueId: mismatch == 'venue'
                      ? 'another-venue'
                      : 'venue-analytics',
                ),
              );
        await _openDetail(tester, _event(venueId: 'venue-analytics'));
        expect(tracker.details, isEmpty);
        expect(analytics.reads, isEmpty);
      });
    }

    for (final owner in [false, true]) {
      testWidgets(
        'event analytics link loads only for its owner on tap=$owner',
        (tester) async {
          details().result = Result.success(_analyticsDetail());
          final sessions = _DetailSessionManager(
            _detailSession(
              userId: owner ? 'venue-owner-id' : 'another-venue-owner',
              roles: const ['ROLE_VENUE'],
            ),
          );
          serviceLocator.registerSingleton<AuthSessionManager>(sessions);
          await _openDetail(
            tester,
            _event(venueId: 'venue-analytics'),
            reportingConfig: const VenueAnalyticsReportingConfig(enabled: true),
          );
          expect(analytics.reads, isEmpty);
          expect(tracker.details, owner ? isEmpty : ['event-design-1']);
          expect(find.text('4.242'), findsNothing);
          final link = find.byKey(const Key('analytics-open-link'));
          expect(link, owner ? findsOneWidget : findsNothing);
          if (owner) {
            await tester.ensureVisible(link);
            await tester.tap(link);
            await tester.pumpAndSettle();
            expect(analytics.reads, ['event-design-1']);
            expect(find.text('Etkinlik istatistikleri'), findsOneWidget);
            expect(find.text('4.242'), findsOneWidget);
            sessions.current = const AuthSession.guest();
            await tester.pumpAndSettle();
            expect(find.text('4.242'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('verified detail carries source through the venue route', (
      tester,
    ) async {
      details().result = Result.success(_analyticsDetail());
      final routes = <RouteSettings>[];
      await _openDetail(
        tester,
        _event(venueId: 'venue-analytics'),
        onRoute: routes.add,
      );
      final chip = find.byKey(const Key('event-venue-profile-chip'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(routes.single.name, AppRoutes.venuePublicProfile);
      final args = routes.single.arguments! as VenuePublicProfileArgs;
      expect(args.venueId, 'venue-analytics');
      expect(args.sourceEventId, 'event-design-1');
      expect(tracker.details, isNotEmpty);
    });

    for (final owner in [false, true]) {
      testWidgets(
        'default-off verified detail hides reporting and preserves collection owner=$owner',
        (tester) async {
          details().result = Result.success(_analyticsDetail());
          serviceLocator.registerSingleton<AuthSessionManager>(
            _DetailSessionManager(
              _detailSession(
                userId: owner ? 'venue-owner-id' : 'another-venue-owner',
                roles: const ['ROLE_VENUE'],
              ),
            ),
          );
          await _openDetail(tester, _event(venueId: 'venue-analytics'));
          expect(find.byKey(const Key('analytics-open-link')), findsNothing);
          expect(find.text('İstatistikleri gör'), findsNothing);
          expect(analytics.reads, isEmpty);
          expect(tracker.details, owner ? isEmpty : ['event-design-1']);
          expect(find.text('Sorular & Yorumlar'), findsOneWidget);
        },
      );
    }
  });
}

VenueEventDetail _analyticsDetail({
  String eventId = 'event-design-1',
  String venueId = 'venue-analytics',
}) => VenueEventDetail(
  id: eventId,
  venueId: venueId,
  shareUrl: null,
  posterImage: null,
  performerName: 'bugrasahin',
  musicianProfileId: null,
  description: 'Gerçek etkinlik açıklaması',
);

class _DetailAnalyticsTracker extends Fake implements AnalyticsTracker {
  final details = <String>[];
  @override
  void recordEventDetailView(String eventId) => details.add(eventId);
}

class _DetailAnalyticsRepository extends Fake
    implements VenueAnalyticsRepository {
  final reads = <String>[];
  @override
  Future<Result<VenueAnalyticsSummary>> event({
    required String venueId,
    required String eventId,
    required String expectedSessionKey,
    int days = 30,
  }) async {
    reads.add(eventId);
    return Result.success(
      VenueAnalyticsSummary(
        venueId: venueId,
        eventId: eventId,
        fromDate: DateTime(2026, 8, 10),
        toDate: DateTime(2026, 9, 8),
        days: days,
        timeZone: 'Europe/Istanbul',
        trackingStartedAt: DateTime.utc(2026, 9, 8),
        updatedAt: DateTime.utc(2026, 9, 8),
        metrics: const VenueAnalyticsMetrics(
          impressions: 4242,
          detailViews: 246,
          profileVisits: 83,
        ),
      ),
    );
  }
}
