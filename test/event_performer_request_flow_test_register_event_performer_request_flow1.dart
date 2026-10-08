part of 'event_performer_request_flow_test.dart';

void _registerEventPerformerRequestFlow1() {
  group('event performer request repository', () {
    test(
      'session fence binds performer decision and suppresses switched observer',
      () async {
        String? session = 'founder-a';
        final api = _PerformerRequestApiClient([])
          ..pendingDecision = Completer<void>();
        var invalidations = 0;
        final repository = EventPerformerRequestRepositoryImpl(
          api,
          sessionKeyProvider: () => session,
          onDecision: () => invalidations++,
        );
        final result = repository.accept('request-1');
        expect(api.requestContext?.expectedSessionKey, 'founder-a');
        session = 'founder-b';
        api.pendingDecision!.complete();
        expect((await result).error?.code, 'event_performer_session_changed');
        expect(invalidations, 0);
        session = null;
        expect((await repository.reject('request-2')).isSuccess, isFalse);
        expect((await repository.listMine()).isSuccess, isFalse);
        expect(api.postPaths.length, 1);
        expect(api.getPaths, isEmpty);
      },
    );

    test(
      'performer observer failure cannot report a committed decision as failure',
      () async {
        final repository = EventPerformerRequestRepositoryImpl(
          _PerformerRequestApiClient([]),
          onDecision: () => throw StateError('observer failed'),
        );
        expect((await repository.accept('request-1')).isSuccess, isTrue);
      },
    );

    test(
      'loads one requested page and exposes stable pagination metadata',
      () async {
        final api = _PerformerRequestApiClient(<Object?>[
          <String, dynamic>{
            'page': 0,
            'number': 0,
            'size': 20,
            'totalElements': 21,
            'totalPages': 2,
            'first': true,
            'last': false,
            'content': <Object?>[
              <String, dynamic>{
                'id': 'request-1',
                'eventId': 'event-1',
                'eventTitle': 'Sahbaz Gecesi',
                'eventDate': '2026-09-08',
                'startTime': '21:00:00',
                'venueId': 'venue-1',
                'venueName': 'SoundConnect Ankara',
                'performerType': 'BAND',
                'bandId': 'band-1',
                'performerName': 'Sahbaz',
                'status': 'PENDING',
              },
            ],
          },
        ]);
        final repository = EventPerformerRequestRepositoryImpl(api);

        final result = await repository.listMine();

        expect(result.isSuccess, isTrue);
        expect(result.data?.page, 0);
        expect(result.data?.hasNext, isTrue);
        expect(result.data?.totalElements, 21);
        expect(result.data?.totalPages, 2);
        final band = result.data!.items.single;
        expect(band.targetType, EventPerformerTargetType.band);
        expect(band.targetId, 'band-1');
        expect(api.getQueries, <Map<String, dynamic>>[
          <String, dynamic>{'status': 'PENDING', 'page': 0, 'size': 20},
        ]);
        expect(api.getPaths, <String>['/api/v1/event-performer-requests/mine']);
      },
    );

    test(
      'sends optional target filter with an explicit page request',
      () async {
        final api = _PerformerRequestApiClient(<Object?>[
          <String, dynamic>{
            'page': 3,
            'number': 3,
            'size': 10,
            'totalElements': 42,
            'totalPages': 5,
            'first': false,
            'last': false,
            'content': <Object?>[_requestJson(requestId: 'request-4')],
          },
        ]);
        final repository = EventPerformerRequestRepositoryImpl(api);

        final result = await repository.listMine(
          page: 3,
          size: 10,
          targetType: EventPerformerTargetType.band,
          targetId: ' band-1 ',
        );

        expect(result.isSuccess, isTrue);
        expect(api.getQueries.single, <String, dynamic>{
          'status': 'PENDING',
          'page': 3,
          'size': 10,
          'targetType': 'BAND',
          'targetId': 'band-1',
        });
      },
    );

    test(
      'rejects malformed page objects instead of treating them as empty',
      () async {
        final api = _PerformerRequestApiClient(<Object?>[
          <String, dynamic>{'unexpected': <Object?>[]},
        ]);
        final repository = EventPerformerRequestRepositoryImpl(api);

        final result = await repository.listMine();

        expect(result.isSuccess, isFalse);
        expect(
          result.error?.code,
          'event_performer_requests_malformed_response',
        );
      },
    );

    test(
      'rejects partial or blank target filters before the request',
      () async {
        final api = _PerformerRequestApiClient(const <Object?>[]);
        final repository = EventPerformerRequestRepositoryImpl(api);

        final missingType = await repository.listMine(targetId: 'band-1');
        final blankId = await repository.listMine(
          targetType: EventPerformerTargetType.band,
          targetId: ' ',
        );

        expect(
          missingType.error?.code,
          'event_performer_requests_invalid_target',
        );
        expect(blankId.error?.code, 'event_performer_requests_invalid_target');
        expect(api.getPaths, isEmpty);
      },
    );

    test(
      'rejects unknown states and contradictory performer targets',
      () async {
        final malformedItems = <Map<String, dynamic>>[
          <String, dynamic>{..._requestJson(), 'performerType': 'VENUE'},
          <String, dynamic>{..._requestJson(), 'status': 'UNKNOWN'},
          <String, dynamic>{..._requestJson(), 'targetId': 'band-other'},
          <String, dynamic>{..._requestJson(), 'targetType': 'MUSICIAN'},
          <String, dynamic>{..._requestJson(), 'requestId': 'request-other'},
          <String, dynamic>{
            ..._requestJson(),
            'musicianProfileId': 'musician-forbidden',
          },
        ];

        for (final item in malformedItems) {
          final repository = EventPerformerRequestRepositoryImpl(
            _PerformerRequestApiClient(<Object?>[
              <Object?>[item],
            ]),
          );
          final result = await repository.listMine();
          expect(
            result.error?.code,
            'event_performer_requests_malformed_response',
          );
        }
      },
    );

    test('keeps legacy raw-list responses supported', () async {
      final api = _PerformerRequestApiClient(<Object?>[
        <Object?>[_requestJson()],
      ]);
      final repository = EventPerformerRequestRepositoryImpl(api);

      final result = await repository.listMine();

      expect(result.isSuccess, isTrue);
      expect(result.data?.items.single.requestId, 'request-1');
      expect(result.data?.hasNext, isFalse);
    });

    test(
      'accepts a concurrent empty out-of-range page as exhaustion',
      () async {
        final repository = EventPerformerRequestRepositoryImpl(
          _PerformerRequestApiClient(<Object?>[
            <String, dynamic>{
              'page': 1,
              'number': 1,
              'size': 20,
              'totalElements': 1,
              'totalPages': 1,
              'first': false,
              'last': true,
              'content': const <Object?>[],
            },
          ]),
        );

        final result = await repository.listMine(page: 1);

        expect(result.isSuccess, isTrue);
        expect(result.data?.isOutOfRange, isTrue);
        expect(result.data?.hasNext, isFalse);
      },
    );

    test('rejects legacy lists after the first page', () async {
      final repository = EventPerformerRequestRepositoryImpl(
        _PerformerRequestApiClient(<Object?>[
          <Object?>[_requestJson()],
        ]),
      );

      final result = await repository.listMine(page: 1);

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'event_performer_requests_malformed_response');
    });

    test(
      'rejects inconsistent totals, page size, status, and duplicate ids',
      () async {
        final malformedPages = <Map<String, dynamic>>[
          <String, dynamic>{
            'page': 0,
            'size': 19,
            'totalElements': 1,
            'totalPages': 1,
            'first': true,
            'last': true,
            'content': <Object?>[_requestJson()],
          },
          <String, dynamic>{
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 2,
            'first': true,
            'last': false,
            'content': <Object?>[_requestJson()],
          },
          <String, dynamic>{
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
            'first': true,
            'last': true,
            'content': <Object?>[
              <String, dynamic>{..._requestJson(), 'status': 'ACCEPTED'},
            ],
          },
          <String, dynamic>{
            'page': 0,
            'size': 20,
            'totalElements': 2,
            'totalPages': 1,
            'first': true,
            'last': true,
            'content': <Object?>[_requestJson(), _requestJson()],
          },
        ];

        for (final payload in malformedPages) {
          final result = await EventPerformerRequestRepositoryImpl(
            _PerformerRequestApiClient(<Object?>[payload]),
          ).listMine();
          expect(
            result.error?.code,
            'event_performer_requests_malformed_response',
          );
        }
      },
    );

    test('uses stable idempotent decision endpoints', () async {
      final api = _PerformerRequestApiClient(const <Object?>[]);
      var calendarInvalidations = 0;
      final repository = EventPerformerRequestRepositoryImpl(
        api,
        onDecision: () => calendarInvalidations++,
      );

      expect((await repository.accept(' request-1 ')).isSuccess, isTrue);
      expect((await repository.reject('request-2')).isSuccess, isTrue);
      expect(calendarInvalidations, 2);
      expect((await repository.accept(' ')).isSuccess, isFalse);
      expect(calendarInvalidations, 2);
      expect(api.postPaths, <String>[
        '/api/v1/event-performer-requests/request-1/accept',
        '/api/v1/event-performer-requests/request-2/reject',
      ]);
    });
  });

  group('event profile link eligibility', () {
    test('pending snapshot has a name without exposing a profile link', () {
      final item = VenueOwnerEventItem.fromJson(<String, dynamic>{
        'id': 'event-1',
        'performerName': 'Sahbaz',
        'performerType': 'MANUAL',
        'eventDate': '2026-09-08',
      });
      final event = WeeklyCalendarEvent(
        id: item.id,
        title: item.title,
        artistName: item.performerName,
        artistProfileId: item.musicianProfileId,
        bandProfileId: item.bandId,
        performerType: item.performerType,
        venueName: 'Mekan',
        venueId: 'venue-1',
        city: '-',
        district: '-',
        neighborhood: '-',
        eventDate: '-',
        startTime: '-',
        endTime: '-',
        description: '',
      );

      expect(event.artistName, 'Sahbaz');
      expect(event.performerType, 'MANUAL');
      expect(event.hasLinkedPerformerProfile, isFalse);
    });

    test('accepted band id enables the band profile link', () {
      final item = VenueOwnerEventItem.fromJson(<String, dynamic>{
        'id': 'event-1',
        'performerName': 'Sahbaz',
        'performerType': 'BAND',
        'bandId': 'band-1',
        'eventDate': '2026-09-08',
      });
      final event = WeeklyCalendarEvent(
        id: item.id,
        title: item.title,
        artistName: item.performerName,
        artistProfileId: item.musicianProfileId,
        bandProfileId: item.bandId,
        performerType: item.performerType,
        venueName: 'Mekan',
        venueId: 'venue-1',
        city: '-',
        district: '-',
        neighborhood: '-',
        eventDate: '-',
        startTime: '-',
        endTime: '-',
        description: '',
      );

      expect(event.hasLinkedPerformerProfile, isTrue);
      expect(event.hasLinkedBandProfile, isTrue);
    });

    test('declared type and exclusive id must agree before linking', () {
      final manualWithLeakedId = _calendarEvent(
        artistProfileId: 'musician-unapproved',
        performerType: 'MANUAL',
      );
      final contradictoryBand = _calendarEvent(
        artistProfileId: 'musician-id',
        bandProfileId: 'band-id',
        performerType: 'BAND',
      );

      expect(manualWithLeakedId.hasLinkedPerformerProfile, isFalse);
      expect(manualWithLeakedId.linkedArtistProfileId, isNull);
      expect(contradictoryBand.hasLinkedPerformerProfile, isFalse);
      expect(contradictoryBand.linkedBandProfileId, isNull);
    });
  });

  group('event performer profile navigation', () {
    setUp(() async {
      await serviceLocator.reset();
      serviceLocator.registerSingleton<VenueEventRepository>(
        _DetailVenueEventRepository(),
      );
      serviceLocator.registerSingleton<EngagementRepository>(
        _NoopEngagementRepository(),
      );
      serviceLocator.registerSingleton<MusicianProfileRepository>(
        _UnavailableMusicianProfileRepository(),
      );
      serviceLocator.registerSingleton<BandRepository>(
        _UnavailableBandRepository(),
      );
    });

    tearDown(serviceLocator.reset);

    testWidgets('pending performer chip is visible but cannot navigate', (
      tester,
    ) async {
      RouteSettings? pushedSettings;
      await tester.pumpWidget(
        _eventNavigationApp(
          event: _calendarEvent(),
          onRoute: (settings) => pushedSettings = settings,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@Sahbaz'), findsNothing);
      expect(find.text('Sahbaz'), findsOneWidget);
      expect(
        find.byKey(const Key('event-performer-verification-info')),
        findsOneWidget,
      );
      await tester.tap(find.text('Sahbaz'));
      await tester.pumpAndSettle();

      expect(pushedSettings, isNull);
      expect(
        find.byKey(const Key('event-performer-verification-dialog')),
        findsNothing,
      );
    });

    testWidgets('accepted musician chip routes to the fresh musician id', (
      tester,
    ) async {
      serviceLocator.registerSingleton<AuthSessionManager>(
        _ApprovalChoiceSession()
          ..signIn('event-viewer', roles: const ['ROLE_LISTENER']),
      );
      RouteSettings? pushedSettings;
      await tester.pumpWidget(
        _eventNavigationApp(
          event: _calendarEvent(artistProfileId: 'musician-fresh'),
          onRoute: (settings) => pushedSettings = settings,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@Sahbaz'), findsOneWidget);
      expect(
        find.byKey(const Key('event-performer-verification-info')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('event-performer-profile-chip')));
      await tester.pumpAndSettle();

      expect(pushedSettings?.name, AppRoutes.musicianPublicProfile);
      expect(
        (pushedSettings?.arguments as PublicProfileArgs).profileId,
        'musician-fresh',
      );
    });

    testWidgets('accepted band chip routes to the fresh band id', (
      tester,
    ) async {
      serviceLocator.registerSingleton<AuthSessionManager>(
        _ApprovalChoiceSession()
          ..signIn('event-viewer', roles: const ['ROLE_LISTENER']),
      );
      RouteSettings? pushedSettings;
      await tester.pumpWidget(
        _eventNavigationApp(
          event: _calendarEvent(bandProfileId: 'band-fresh'),
          onRoute: (settings) => pushedSettings = settings,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@Sahbaz'), findsOneWidget);
      expect(
        find.byKey(const Key('event-performer-verification-info')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('event-performer-profile-chip')));
      await tester.pumpAndSettle();

      expect(pushedSettings?.name, AppRoutes.bandPublicProfile);
      final args = pushedSettings?.arguments as BandProfileScreenArgs;
      expect(args.bandId, 'band-fresh');
      expect(args.viewMode, BandProfileViewMode.public);
    });
  });

  group('event carousel state isolation', () {
    setUp(() async {
      await serviceLocator.reset();
    });

    tearDown(serviceLocator.reset);

    testWidgets('an in-flight old card response cannot populate a new event', (
      tester,
    ) async {
      final repository = _DeferredVenueEventRepository();
      serviceLocator.registerSingleton<VenueEventRepository>(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyEventCarousel(
              now: () => DateTime.utc(2026, 9, 8, 12),
              items: <WeeklyCalendarEvent>[_pendingCarouselEvent('event-a')],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(repository.requestedIds, <String>['event-a']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyEventCarousel(
              now: () => DateTime.utc(2026, 9, 8, 12),
              items: <WeeklyCalendarEvent>[_pendingCarouselEvent('event-b')],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(repository.requestedIds, <String>['event-a', 'event-b']);

      repository.complete('event-b', performerName: 'Güncel Sanatçı');
      await tester.pump();
      repository.complete('event-a', performerName: 'Eski Sanatçı');
      await tester.pumpAndSettle();

      expect(find.text('Güncel Sanatçı'), findsOneWidget);
      expect(find.text('Eski Sanatçı'), findsNothing);
    });

    testWidgets(
      'resolved performer cache evicts its oldest entry at capacity',
      (tester) async {
        final repository = _CountingMusicianProfileRepository();
        serviceLocator.registerSingleton<MusicianProfileRepository>(repository);

        for (var index = 0; index <= 256; index++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WeeklyEventCarousel(
                  now: () => DateTime.utc(2026, 9, 8, 12),
                  items: <WeeklyCalendarEvent>[_acceptedCarouselEvent(index)],
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WeeklyEventCarousel(
                now: () => DateTime.utc(2026, 9, 8, 12),
                items: <WeeklyCalendarEvent>[_acceptedCarouselEvent(0)],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(repository.calls['cache-musician-0'], 2);
      },
    );
  });
}
