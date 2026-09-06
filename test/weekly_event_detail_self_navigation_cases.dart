part of 'weekly_event_detail_design_test.dart';

void _selfProfileNavigationTests(_MusicianRepository Function() repository) {
  group('event performer self navigation', () {
    late _DetailSessionManager sessionManager;

    setUp(() {
      sessionManager = _DetailSessionManager(_detailSession());
      serviceLocator.registerSingleton<AuthSessionManager>(sessionManager);
    });

    testWidgets('verified loaded self opens owner route without public args', (
      tester,
    ) async {
      repository().result = Result.success(_navigationProfile());
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);

      final open = _performerNameInkWell(tester, '@bugrasahin').onTap!;
      open();
      open();
      await tester.pumpAndSettle();

      expect(routes, hasLength(1));
      expect(routes.single.name, AppRoutes.musicianProfile);
      expect(routes.single.arguments, isNull);
      expect(repository().myReads, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'returning from own profile preserves detail and allows reopen',
      (tester) async {
        repository().result = Result.success(_navigationProfile());
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _linkedNavigationEvent(),
          onRoute: routes.add,
        );
        final detail = find.byType(WeeklyEventDetailScreen);
        final originalState = tester.state(detail);
        final navigator = Navigator.of(tester.element(detail));

        await _tapLinkedPerformer(tester);
        expect(routes.single.name, AppRoutes.musicianProfile);
        expect(navigator.canPop(), isTrue);
        navigator.pop();
        await tester.pumpAndSettle();

        expect(detail, findsOneWidget);
        expect(tester.state(detail), same(originalState));
        expect(find.text('M-T1 — Katıl, gösterme'), findsOneWidget);
        expect(navigator.canPop(), isFalse);
        await _tapLinkedPerformer(tester);

        expect(routes, hasLength(2));
        expect(routes.last.name, AppRoutes.musicianProfile);
        expect(routes.last.arguments, isNull);
        expect(navigator.canPop(), isTrue);
        expect(repository().requestedIds, ['musician-approved']);
        expect(repository().myReads, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('same username owned by another user remains public', (
      tester,
    ) async {
      repository().result = Result.success(
        _navigationProfile(userId: 'different-user'),
      );
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);
      await _tapLinkedPerformer(tester);

      _expectPublicNavigation(routes);
      expect(repository().myReads, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('different public profile id cannot establish self identity', (
      tester,
    ) async {
      repository()
        ..result = Result.success(_navigationProfile(id: 'wrong-public-id'))
        ..myResult = Result.success(_navigationProfile(id: 'my-other-profile'));
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);
      await _tapLinkedPerformer(tester);

      _expectPublicNavigation(routes);
      expect(repository().myReads, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fast taps while public profile loads perform one own lookup', (
      tester,
    ) async {
      final public = Completer<Result<MusicianProfile>>();
      final mine = Completer<Result<MusicianProfile>>();
      repository()
        ..completion = public
        ..myCompletion = mine;
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);
      expect(repository().myReads, 0);
      final open = _performerNameInkWell(tester, '@bugrasahin').onTap!;
      open();
      open();
      await tester.pump();
      expect(repository().myReads, 1);
      expect(routes, isEmpty);

      mine.complete(Result.success(_navigationProfile()));
      await tester.pumpAndSettle();
      expect(routes, hasLength(1));
      expect(routes.single.name, AppRoutes.musicianProfile);
      expect(routes.single.arguments, isNull);
      public.complete(Result.success(_navigationProfile()));
      await tester.pumpAndSettle();
      expect(routes, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    for (final throws in [false, true]) {
      testWidgets(
        'failed own lookup stays on detail and allows retry ($throws)',
        (tester) async {
          repository().throwMyRead = throws;
          final routes = <RouteSettings>[];
          await _openDetail(
            tester,
            _linkedNavigationEvent(),
            onRoute: routes.add,
          );
          await _tapLinkedPerformer(tester);
          expect(routes, isEmpty);
          expect(repository().myReads, 1);
          expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
          expect(find.byType(SnackBar), findsOneWidget);

          repository()
            ..throwMyRead = false
            ..myResult = Result.success(_navigationProfile());
          await _tapLinkedPerformer(tester);
          expect(routes, hasLength(1));
          expect(routes.single.name, AppRoutes.musicianProfile);
          expect(repository().myReads, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final invalid in [
      _navigationProfile(userId: 'different-user'),
      _navigationProfile(userId: ''),
      _navigationProfile(id: ''),
    ]) {
      testWidgets(
        'own lookup requires matching user and nonempty profile (${invalid.id}/${invalid.userId})',
        (tester) async {
          repository().myResult = Result.success(invalid);
          final routes = <RouteSettings>[];
          await _openDetail(
            tester,
            _linkedNavigationEvent(),
            onRoute: routes.add,
          );
          await _tapLinkedPerformer(tester);

          expect(routes, isEmpty);
          expect(repository().myReads, 1);
          expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final change in <String, AuthSession>{
      'account': _detailSession(userId: 'new-account'),
      'logout': const AuthSession.guest(),
      'token': _detailSession(token: 'new-token'),
      'status': _detailSession(status: 'SUSPENDED'),
      'role': _detailSession(roles: const ['ROLE_LISTENER']),
    }.entries) {
      testWidgets('session ${change.key} change discards pending own lookup', (
        tester,
      ) async {
        final mine = Completer<Result<MusicianProfile>>();
        repository().myCompletion = mine;
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _linkedNavigationEvent(),
          onRoute: routes.add,
        );
        _performerNameInkWell(tester, '@bugrasahin').onTap!();
        await tester.pump();
        expect(repository().myReads, 1);

        sessionManager.current = change.value;
        mine.complete(Result.success(_navigationProfile()));
        await tester.pumpAndSettle();
        expect(routes, isEmpty);
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('changing linked performer discards pending own lookup', (
      tester,
    ) async {
      final mine = Completer<Result<MusicianProfile>>();
      repository().myCompletion = mine;
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);
      _performerNameInkWell(tester, '@bugrasahin').onTap!();
      await tester.pump();

      await _openDetail(
        tester,
        _event(
          artistProfileId: 'replacement-musician',
          performerType: 'MUSICIAN',
        ),
        onRoute: routes.add,
      );
      mine.complete(Result.success(_navigationProfile()));
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(repository().myReads, 1);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing detail discards pending lookup and queued callback', (
      tester,
    ) async {
      final mine = Completer<Result<MusicianProfile>>();
      repository().myCompletion = mine;
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);
      final open = _performerNameInkWell(tester, '@bugrasahin').onTap!;
      open();
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      mine.complete(Result.success(_navigationProfile()));
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(repository().myReads, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('covering detail discards lookup and blocks stale callback', (
      tester,
    ) async {
      final mine = Completer<Result<MusicianProfile>>();
      repository().myCompletion = mine;
      final routes = <RouteSettings>[];
      await _openDetail(tester, _linkedNavigationEvent(), onRoute: routes.add);
      final open = _performerNameInkWell(tester, '@bugrasahin').onTap!;
      final navigator = Navigator.of(
        tester.element(find.byType(WeeklyEventDetailScreen)),
      );
      open();
      await tester.pump();
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Covering profile detail')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      mine.complete(Result.success(_navigationProfile()));
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(find.text('Covering profile detail'), findsOneWidget);
      expect(repository().myReads, 1);
      expect(tester.takeException(), isNull);
    });

    for (final viewer in <String, AuthSession>{
      'guest': const AuthSession.guest(),
      'listener': _detailSession(roles: const ['ROLE_LISTENER']),
      'inactive musician': _detailSession(status: 'SUSPENDED'),
    }.entries) {
      testWidgets('${viewer.key} remains public without own lookup', (
        tester,
      ) async {
        sessionManager.current = viewer.value;
        repository().result = Result.success(_navigationProfile());
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _linkedNavigationEvent(),
          onRoute: routes.add,
        );
        await _tapLinkedPerformer(tester);

        _expectPublicNavigation(routes);
        expect(repository().myReads, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'public identity without owner falls back to verified own lookup',
      (tester) async {
        repository()
          ..result = Result.success(_navigationProfile(userId: ''))
          ..myResult = Result.success(_navigationProfile());
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _linkedNavigationEvent(),
          onRoute: routes.add,
        );
        expect(repository().myReads, 0);
        await _tapLinkedPerformer(tester);

        expect(routes, hasLength(1));
        expect(routes.single.name, AppRoutes.musicianProfile);
        expect(repository().myReads, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('self matching event still requires approved linked identity', (
      tester,
    ) async {
      repository()
        ..result = Result.success(_navigationProfile())
        ..myResult = Result.success(_navigationProfile());
      final routes = <RouteSettings>[];
      await _openDetail(
        tester,
        _event(artistProfileId: 'musician-approved', performerType: 'MANUAL'),
        onRoute: routes.add,
      );

      expect(_performerNameInkWell(tester, 'bugrasahin').onTap, isNull);
      expect(find.text('@bugrasahin'), findsNothing);
      expect(routes, isEmpty);
      expect(repository().requestedIds, isEmpty);
      expect(repository().myReads, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('musician viewing band preserves public band policy', (
      tester,
    ) async {
      final routes = <RouteSettings>[];
      await _openDetail(
        tester,
        _event(
          artistName: 'Şahbaz',
          bandProfileId: 'band-approved',
          performerType: 'BAND',
        ),
        onRoute: routes.add,
      );
      await _tapLinkedPerformer(tester);
      expect(routes, hasLength(1));
      expect(routes.single.name, AppRoutes.bandPublicProfile);
      final args = routes.single.arguments as BandProfileScreenArgs;
      expect(args.bandId, 'band-approved');
      expect(args.viewMode, BandProfileViewMode.public);
      expect(repository().requestedIds, isEmpty);
      expect(repository().myReads, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _tapLinkedPerformer(WidgetTester tester) async {
  final chip = find.byKey(const Key('event-performer-profile-chip'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void _expectPublicNavigation(List<RouteSettings> routes) {
  expect(routes, hasLength(1));
  expect(routes.single.name, AppRoutes.musicianPublicProfile);
  expect(
    (routes.single.arguments as PublicProfileArgs).profileId,
    'musician-approved',
  );
}

WeeklyCalendarEvent _linkedNavigationEvent() =>
    _event(artistProfileId: 'musician-approved', performerType: 'MUSICIAN');

MusicianProfile _navigationProfile({
  String id = 'musician-approved',
  String userId = 'musician-user',
}) => MusicianProfile(
  id: id,
  userId: userId,
  username: 'bugrasahin',
  stageName: null,
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  spotifyTracks: const [],
  instruments: const [],
  activeVenues: const [],
  bands: const [],
);

AuthSession _detailSession({
  String token = 'musician-token',
  String userId = 'musician-user',
  String status = 'ACTIVE',
  List<String> roles = const ['ROLE_MUSICIAN'],
}) => AuthSession.authenticated(
  token: token,
  userId: userId,
  username: 'bugrasahin',
  accountStatus: status,
  roles: roles,
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
);

class _DetailSessionManager extends Fake implements AuthSessionManager {
  AuthSession current;

  _DetailSessionManager(this.current);

  @override
  AuthSession get session => current;
}
