part of 'venue_artists_profile_entry_test.dart';

void _venueProfileAnalyticsTests(_Profiles Function() profiles) {
  for (final source in [null, 'source-event']) {
    testWidgets(
      'actual public venue profile records successful visit with source $source',
      (tester) async {
        final tracker = _VenueTracker();
        serviceLocator.registerSingleton<AnalyticsTracker>(tracker);
        final pending = Completer<Result<VenuePublicProfile>>();
        profiles().publicReply = () => pending.future;
        await _mountTrackedVenue(tester, source: source, settle: false);
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.visits, isEmpty);
        pending.complete(const Result.success(_public));
        await tester.pumpAndSettle();
        await tester.pump();
        expect(tracker.visits, [('actual-venue', source)]);
        await tester.pump(const Duration(seconds: 2));
        expect(tracker.visits, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets('actual failed public venue profile never records a visit', (
    tester,
  ) async {
    final tracker = _VenueTracker();
    serviceLocator.registerSingleton<AnalyticsTracker>(tracker);
    profiles().publicReply = () async => const Result.failure(
      AppError(code: 'offline', message: 'Profil yüklenemedi.'),
    );
    await _mountTrackedVenue(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Profil yüklenemedi.'), findsOneWidget);
    expect(tracker.visits, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'actual owner venue profile does not observe its own management visit',
    (tester) async {
      final tracker = _VenueTracker();
      serviceLocator.registerSingleton<AnalyticsTracker>(tracker);
      final reporting = _VenueReportingRepository();
      serviceLocator
        ..registerSingleton<AuthSessionManager>(_VenueOwnerSession())
        ..registerSingleton<VenueAnalyticsRepository>(reporting);
      await _mountTrackedVenue(tester, owner: true);
      await tester.pump(const Duration(seconds: 2));
      expect(profiles().ownerReads, ['actual-venue']);
      expect(tracker.visits, isEmpty);
      expect(find.byKey(const Key('analytics-open-link')), findsNothing);
      expect(find.text('İstatistikleri gör'), findsNothing);
      expect(reporting.reads, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'explicit reporting scope restores actual owner profile link without eager reads',
    (tester) async {
      final reporting = _VenueReportingRepository();
      serviceLocator
        ..registerSingleton<AuthSessionManager>(_VenueOwnerSession())
        ..registerSingleton<VenueAnalyticsRepository>(reporting);
      await _mountTrackedVenue(
        tester,
        owner: true,
        reportingConfig: const VenueAnalyticsReportingConfig(enabled: true),
      );
      expect(find.byKey(const Key('analytics-open-link')), findsOneWidget);
      expect(reporting.reads, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'public venue payload mismatching the requested venue is not counted',
    (tester) async {
      final tracker = _VenueTracker();
      serviceLocator.registerSingleton<AnalyticsTracker>(tracker);
      await _mountTrackedVenue(tester, venue: 'other-venue');
      await tester.pump(const Duration(seconds: 2));
      expect(profiles().publicReads, ['other-venue']);
      expect(tracker.visits, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Future<void> _mountTrackedVenue(
  WidgetTester tester, {
  String? source,
  bool owner = false,
  bool settle = true,
  String venue = 'actual-venue',
  VenueAnalyticsReportingConfig? reportingConfig,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final application = MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    navigatorObservers: [analyticsRouteObserver],
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      settings: RouteSettings(
        arguments: owner
            ? VenueProfileArgs(venueId: venue, viewerUserId: 'owner')
            : VenuePublicProfileArgs(
                venueId: venue,
                viewerUserId: 'visitor',
                sourceEventId: source,
              ),
      ),
      builder: (_) =>
          owner ? const VenueProfileScreen() : const VenuePublicProfileScreen(),
    ),
  );
  await tester.pumpWidget(
    reportingConfig == null
        ? application
        : VenueAnalyticsReportingScope(
            config: reportingConfig,
            child: application,
          ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _VenueTracker extends Fake implements AnalyticsTracker {
  final visits = <(String, String?)>[];
  @override
  void recordVenueProfileView(String venueId, {String? sourceEventId}) =>
      visits.add((venueId, sourceEventId));
}

class _VenueOwnerSession extends Fake
    with ChangeNotifier
    implements AuthSessionManager {
  @override
  AuthSession get session => AuthSession.authenticated(
    token: 'owner-test-token',
    userId: 'owner',
    username: 'owner',
    accountStatus: 'ACTIVE',
    roles: const ['ROLE_VENUE'],
    permissions: const [],
    expiresAt: DateTime.utc(2100),
    isAdmin: false,
  );
}

class _VenueReportingRepository extends Fake
    implements VenueAnalyticsRepository {
  final reads = <Symbol>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    reads.add(invocation.memberName);
    return super.noSuchMethod(invocation);
  }
}
