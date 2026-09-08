part of 'weekly_event_detail_design_test.dart';

void _bandProfileNavigationTests(_BandRepository Function() repository) {
  group('event band owner navigation', () {
    late _DetailSessionManager sessionManager;

    setUp(() {
      sessionManager = _DetailSessionManager(_detailSession());
      serviceLocator.registerSingleton<AuthSessionManager>(sessionManager);
    });

    testWidgets('active founder opens auto owner route without another read', (
      tester,
    ) async {
      repository().result = Result.success(_navigationBand());
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      final open = _performerNameInkWell(tester, '@Şahbaz').onTap!;
      open();
      open();
      await tester.pumpAndSettle();

      _expectBandNavigation(routes, own: true);
      expect(repository().requestedIds, ['band-approved']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('founder role and status normalize surrounding whitespace', (
      tester,
    ) async {
      repository().result = Result.success(
        _navigationBand(role: ' founder ', status: ' active '),
      );
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      await _tapLinkedPerformer(tester);

      _expectBandNavigation(routes, own: true);
      expect(tester.takeException(), isNull);
    });

    for (final membership in <String, BandProfile>{
      'another founder with the same username': _navigationBand(
        userId: 'other-founder',
      ),
      'active regular member': _navigationBand(role: 'MEMBER'),
      'active manager': _navigationBand(role: 'MANAGER'),
      'inactive founder': _navigationBand(status: 'INACTIVE'),
      'pending founder': _navigationBand(status: 'PENDING'),
      'missing founder user ID': _navigationBand(userId: ''),
      'no members': _navigationBand(includeMember: false),
    }.entries) {
      testWidgets('${membership.key} stays in public band mode', (
        tester,
      ) async {
        repository().result = Result.success(membership.value);
        final routes = <RouteSettings>[];
        await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
        await _tapLinkedPerformer(tester);

        _expectBandNavigation(routes, own: false);
        expect(repository().requestedIds, ['band-approved']);
        expect(tester.takeException(), isNull);
      });
    }

    for (final viewer in <String, AuthSession>{
      'guest': const AuthSession.guest(),
      'listener': _detailSession(roles: const ['ROLE_LISTENER']),
      'venue': _detailSession(roles: const ['ROLE_VENUE']),
      'inactive musician': _detailSession(status: 'SUSPENDED'),
      'missing viewer ID': _detailSession(userId: ''),
    }.entries) {
      testWidgets('${viewer.key} cannot open founder mode or trigger lookup', (
        tester,
      ) async {
        sessionManager.current = viewer.value;
        repository().result = Result.success(_navigationBand());
        final routes = <RouteSettings>[];
        await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
        await _tapLinkedPerformer(tester);

        _expectBandNavigation(routes, own: false);
        expect(repository().requestedIds, ['band-approved']);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('fast repeated taps share one pending band identity lookup', (
      tester,
    ) async {
      final pending = Completer<Result<BandProfile>>();
      repository().completion = pending;
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      final open = _performerNameInkWell(tester, '@Şahbaz').onTap!;
      open();
      open();
      await tester.pump();

      expect(repository().requestedIds, ['band-approved', 'band-approved']);
      expect(routes, isEmpty);
      pending.complete(Result.success(_navigationBand()));
      await tester.pumpAndSettle();

      _expectBandNavigation(routes, own: true);
      expect(repository().requestedIds, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    for (final throws in [false, true]) {
      testWidgets(
        'failed band identity read stays on detail and retries ($throws)',
        (tester) async {
          repository().throwRead = throws;
          final routes = <RouteSettings>[];
          await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
          await _tapLinkedPerformer(tester);

          expect(routes, isEmpty);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
          expect(repository().requestedIds, hasLength(2));

          repository()
            ..throwRead = false
            ..result = Result.success(_navigationBand());
          await _tapLinkedPerformer(tester);

          _expectBandNavigation(routes, own: true);
          expect(repository().requestedIds, hasLength(3));
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final invalidId in ['other-band', '']) {
      testWidgets('band payload ID $invalidId cannot establish ownership', (
        tester,
      ) async {
        repository().result = Result.success(_navigationBand(id: invalidId));
        final routes = <RouteSettings>[];
        await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
        await _tapLinkedPerformer(tester);

        expect(routes, isEmpty);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(repository().requestedIds, hasLength(2));
        expect(tester.takeException(), isNull);
      });
    }

    for (final change in <String, AuthSession>{
      'account': _detailSession(userId: 'new-account'),
      'logout': const AuthSession.guest(),
      'token': _detailSession(token: 'new-token'),
      'status': _detailSession(status: 'SUSPENDED'),
      'role': _detailSession(roles: const ['ROLE_LISTENER']),
    }.entries) {
      testWidgets('session ${change.key} change discards pending band route', (
        tester,
      ) async {
        final routes = <RouteSettings>[];
        await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
        final pending = Completer<Result<BandProfile>>();
        repository().completion = pending;
        _performerNameInkWell(tester, '@Şahbaz').onTap!();
        await tester.pump();

        sessionManager.current = change.value;
        pending.complete(Result.success(_navigationBand()));
        await tester.pumpAndSettle();

        expect(routes, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('changing linked band discards the pending owner route', (
      tester,
    ) async {
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      final pending = Completer<Result<BandProfile>>();
      repository().completion = pending;
      _performerNameInkWell(tester, '@Şahbaz').onTap!();
      await tester.pump();
      await _openDetail(
        tester,
        _linkedBandEvent(bandId: 'replacement-band'),
        onRoute: routes.add,
      );
      pending.complete(Result.success(_navigationBand()));
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing detail discards lookup and stale band callback', (
      tester,
    ) async {
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      final pending = Completer<Result<BandProfile>>();
      repository().completion = pending;
      final open = _performerNameInkWell(tester, '@Şahbaz').onTap!;
      open();
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      pending.complete(Result.success(_navigationBand()));
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(repository().requestedIds, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('covering detail discards lookup and stale band callback', (
      tester,
    ) async {
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      final pending = Completer<Result<BandProfile>>();
      repository().completion = pending;
      final open = _performerNameInkWell(tester, '@Şahbaz').onTap!;
      final navigator = Navigator.of(
        tester.element(find.byType(WeeklyEventDetailScreen)),
      );
      open();
      await tester.pump();
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covering band detail')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      pending.complete(Result.success(_navigationBand()));
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(find.text('Covering band detail'), findsOneWidget);
      expect(repository().requestedIds, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner back navigation preserves event and can reopen band', (
      tester,
    ) async {
      repository().result = Result.success(_navigationBand());
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedBandEvent(), onRoute: routes.add);
      final detail = find.byType(WeeklyEventDetailScreen);
      final originalState = tester.state(detail);
      final navigator = Navigator.of(tester.element(detail));
      await _tapLinkedPerformer(tester);
      _expectBandNavigation(routes, own: true);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(tester.state(detail), same(originalState));
      expect(find.text('B-T1 — Grup katılımı'), findsOneWidget);
      await _tapLinkedPerformer(tester);
      expect(routes, hasLength(2));
      expect(routes.last.name, AppRoutes.bandProfile);
      expect(repository().requestedIds, ['band-approved']);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'unapproved band cannot link even if founder identity matches',
      (tester) async {
        repository().result = Result.success(_navigationBand());
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _event(artistName: 'Şahbaz', bandProfileId: 'band-approved'),
          onRoute: routes.add,
        );

        expect(_performerNameInkWell(tester, 'Şahbaz').onTap, isNull);
        expect(find.text('@Şahbaz'), findsNothing);
        expect(repository().requestedIds, isEmpty);
        expect(routes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

WeeklyCalendarEvent _linkedBandEvent({String bandId = 'band-approved'}) =>
    _event(
      title: 'B-T1 — Grup katılımı',
      artistName: 'Şahbaz',
      bandProfileId: bandId,
      performerType: 'BAND',
    );

BandProfile _navigationBand({
  String id = 'band-approved',
  String userId = 'musician-user',
  String role = 'FOUNDER',
  String status = 'ACTIVE',
  bool includeMember = true,
}) => BandProfile(
  id: id,
  name: 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  members: [
    if (includeMember)
      BandMemberSummary(
        userId: userId,
        profileId: 'musician-approved',
        username: 'bugrasahin',
        profilePictureUrl: null,
        role: role,
        status: status,
      ),
  ],
);

void _expectBandNavigation(List<RouteSettings> routes, {required bool own}) {
  expect(routes, hasLength(1));
  expect(
    routes.single.name,
    own ? AppRoutes.bandProfile : AppRoutes.bandPublicProfile,
  );
  final args = routes.single.arguments as BandProfileScreenArgs;
  expect(args.bandId, 'band-approved');
  expect(
    args.viewMode,
    own ? BandProfileViewMode.auto : BandProfileViewMode.public,
  );
  expect(args.openEditMode, isFalse);
}
