import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_performer_request_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

import 'support/auth_widget_test_support.dart';

part 'event_performer_request_flow_test_support.dart';
part 'event_performer_request_publication_test_cases.dart';

void main() {
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

  group('event performer request screen', () {
    _publicationChoiceTests();
    for (final target in EventPerformerTargetType.values) {
      testWidgets('$target can approve while calendar display remains off', (
        tester,
      ) async {
        await serviceLocator.reset();
        addTearDown(serviceLocator.reset);
        final calendar = _DisabledApprovalCalendarRepository();
        serviceLocator.registerSingleton<MusicianCalendarRepository>(calendar);
        final bandCalendar = _DisabledApprovalCalendarRepository();
        final bandCalendars = _DisabledApprovalBandCalendarFactory(
          bandCalendar,
        );
        serviceLocator.registerSingleton<BandCalendarRepositoryFactory>(
          bandCalendars,
        );
        final targetId = target == EventPerformerTargetType.band
            ? 'band-1'
            : 'musician-1';
        final repository = _FakePerformerRequestRepository(
          pages: {
            0: _page([_request(targetType: target, targetId: targetId)]),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              targetType: target,
              targetId: targetId,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Etkinlik Davetleri'), findsOneWidget);
        await _tapRequestControl(
          tester,
          find.byKey(const Key('accept-event-request-request-1')),
        );
        await tester.pumpAndSettle();
        expect(repository.acceptCalls, 1);
        expect(repository.acceptChoices, [('request-1', false)]);
        expect(calendar.reads, 0);
        expect(calendar.updates, 0);
        expect(bandCalendars.acquires, 0);
        expect(bandCalendar.reads, 0);
        expect(bandCalendar.updates, 0);
        expect(find.byType(SwitchListTile), findsNothing);
      });
    }

    testWidgets(
      'account switch during performer rejection confirmation never writes',
      (tester) async {
        var session = 'founder-a';
        final repository = _FakePerformerRequestRepository(
          pages: {
            0: _page([_request()]),
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              sessionKeyProvider: () => session,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tapRequestControl(
          tester,
          find.byKey(const Key('reject-event-request-request-1')),
        );
        // The card has an in-progress indicator while its dialog is open.
        await tester.pump(const Duration(milliseconds: 300));
        session = 'founder-b';
        await tester.tap(find.byKey(const Key('confirm-reject-request-1')));
        await tester.pumpAndSettle();
        expect(repository.rejectCalls, 0);
        expect(find.text('Sahbaz Gecesi'), findsNothing);
        expect(find.textContaining('Oturum değişti'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'account switch during performer page load discards private results',
      (tester) async {
        var session = 'founder-a';
        final pending = Completer<Result<EventPerformerRequestPage>>();
        final repository = _FakePerformerRequestRepository(
          listFutures: [pending.future],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(
              repository: repository,
              sessionKeyProvider: () => session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(repository.listCalls, 1);
        session = 'founder-b';
        pending.complete(Result.success(_page([_request()])));
        await tester.pumpAndSettle();
        expect(find.text('Sahbaz Gecesi'), findsNothing);
        expect(find.textContaining('Oturum değişti'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('accept is single-flight and removes the resolved request', (
      tester,
    ) async {
      final completion = Completer<Result<void>>();
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()]),
        },
        acceptCompletion: completion,
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz Gecesi'), findsOneWidget);
      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
      );
      await tester.pump();
      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
        warnIfMissed: false,
      );
      expect(repository.acceptCalls, 1);

      completion.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
    });

    testWidgets('refresh cannot replay a locally resolved request', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()]),
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await _tapRequestControl(
        tester,
        find.byKey(const Key('accept-event-request-request-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
      expect(
        find.byKey(const Key('accept-event-request-request-1')),
        findsNothing,
      );
      expect(repository.acceptCalls, 1);
    });

    testWidgets(
      'decision reloads page zero so offset shrink cannot skip an item',
      (tester) async {
        // Keep the action in view: this case isolates decision reconciliation,
        // while separate tests exercise scroll-triggered/explicit pagination.
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FakePerformerRequestRepository(
          listResults: <Result<EventPerformerRequestPage>>[
            Result.success(
              _page(<EventPerformerRequest>[_request()], hasNext: true),
            ),
            Result.success(
              _page(<EventPerformerRequest>[
                _request(
                  requestId: 'request-shifted',
                  performerName: 'Sıradaki Grup',
                ),
              ]),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EventPerformerRequestsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('accept-event-request-request-1')),
        );
        await tester.pumpAndSettle();

        expect(repository.requestedPages, <int>[0, 0]);
        expect(find.text('Sıradaki Grup • Grup'), findsOneWidget);
      },
    );

    testWidgets('out-of-range next page reconciles from page zero', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakePerformerRequestRepository(
        listResults: <Result<EventPerformerRequestPage>>[
          Result.success(
            _page(<EventPerformerRequest>[_request()], hasNext: true),
          ),
          const Result.success(
            EventPerformerRequestPage(
              items: <EventPerformerRequest>[],
              page: 1,
              size: 20,
              totalElements: 1,
              totalPages: 1,
              hasNext: false,
            ),
          ),
          Result.success(
            _page(<EventPerformerRequest>[
              _request(
                requestId: 'request-reconciled',
                performerName: 'Güncel Grup',
              ),
            ]),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      // The wide viewport already exposes the footer; scrolling to align it
      // would itself trigger automatic pagination before the explicit tap.
      await tester.tap(
        find.byKey(const Key('load-more-event-performer-requests')),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedPages, <int>[0, 1, 0]);
      expect(find.text('Güncel Grup • Grup'), findsOneWidget);
    });

    testWidgets('band scoped screen hides another target request', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[
            _request(),
            _request(
              requestId: 'request-2',
              targetType: EventPerformerTargetType.musician,
              targetId: 'musician-1',
              performerName: 'Büğra Şahin',
            ),
          ]),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(find.textContaining('Büğra'), findsNothing);
      expect(repository.targetTypes, <EventPerformerTargetType?>[
        EventPerformerTargetType.band,
      ]);
      expect(repository.targetIds, <String?>['band-1']);
    });

    testWidgets('renders the first page then loads the next page on demand', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()], hasNext: true),
          1: _page(<EventPerformerRequest>[
            _request(requestId: 'request-2', performerName: 'İkinci Grup'),
          ], page: 1),
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(repository.requestedPages, <int>[0]);
      await tester.tap(
        find.byKey(const Key('load-more-event-performer-requests')),
      );
      await tester.pumpAndSettle();

      expect(find.text('İkinci Grup • Grup'), findsOneWidget);
      expect(repository.requestedPages, <int>[0, 1]);
    });

    testWidgets('scoped inbox auto-pages before showing an empty state', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[
            _request(
              targetType: EventPerformerTargetType.musician,
              targetId: 'musician-1',
            ),
          ], hasNext: true),
          1: _page(<EventPerformerRequest>[
            _request(requestId: 'request-2', targetId: 'band-2'),
          ], page: 1),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bekleyen etkinlik daveti yok'), findsNothing);
      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(repository.requestedPages, <int>[0, 1]);
    });

    testWidgets('shows an auth-aware error and supports retry', (tester) async {
      final repository = _FakePerformerRequestRepository(
        listResults: <Result<EventPerformerRequestPage>>[
          const Result.failure(
            AppError(code: 'unauthorized', message: 'raw backend message'),
          ),
          Result.success(_page(const <EventPerformerRequest>[])),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('yeniden giriş'), findsOneWidget);
      await _tapRequestControl(
        tester,
        find.byKey(const Key('retry-event-performer-requests')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
      expect(repository.listCalls, 2);
    });

    testWidgets('pull-to-refresh keeps the current page visible in flight', (
      tester,
    ) async {
      final refreshCompletion = Completer<Result<EventPerformerRequestPage>>();
      final repository = _FakePerformerRequestRepository(
        listFutures: <Future<Result<EventPerformerRequestPage>>>[
          Future.value(
            Result.success(_page(<EventPerformerRequest>[_request()])),
          ),
          refreshCompletion.future,
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      expect(find.text('Sahbaz • Grup'), findsOneWidget);

      refreshCompletion.complete(
        Result.success(
          _page(<EventPerformerRequest>[
            _request(requestId: 'request-2', performerName: 'Yeni Grup'),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Yeni Grup • Grup'), findsOneWidget);
      expect(find.text('Sahbaz • Grup'), findsNothing);
    });

    testWidgets('failed refresh preserves the usable current page', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        listResults: <Result<EventPerformerRequestPage>>[
          Result.success(_page(<EventPerformerRequest>[_request()])),
          const Result.failure(
            AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(find.text('Bağlantı kurulamadı.'), findsWidgets);
      expect(
        find.byKey(const Key('retry-event-performer-requests')),
        findsNothing,
      );
    });

    testWidgets('unexpected decision failure restores the action', (
      tester,
    ) async {
      final repository = _FakePerformerRequestRepository(
        pages: <int, EventPerformerRequestPage>{
          0: _page(<EventPerformerRequest>[_request()]),
        },
        throwOnAccept: true,
      );
      await tester.pumpWidget(
        MaterialApp(home: EventPerformerRequestsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final accept = find.byKey(const Key('accept-event-request-request-1'));
      await _tapRequestControl(tester, accept);
      await tester.pumpAndSettle();
      expect(find.text('Sahbaz Gecesi'), findsOneWidget);
      expect(find.text('Etkinlik onayı güncellenemedi.'), findsOneWidget);

      // The longer consent explanation places the action near the snackbar.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(accept);
      await _tapRequestControl(tester, accept);
      await tester.pumpAndSettle();
      expect(repository.acceptCalls, 2);
    });

    testWidgets('scoped fallback paging is bounded and explicitly resumable', (
      tester,
    ) async {
      final pages = <int, EventPerformerRequestPage>{
        for (var page = 0; page < 4; page++)
          page: _page(
            <EventPerformerRequest>[
              _request(
                requestId: 'other-$page',
                targetId: 'another-band-$page',
              ),
            ],
            page: page,
            hasNext: true,
          ),
        4: _page(<EventPerformerRequest>[
          _request(requestId: 'wanted', targetId: 'band-wanted'),
        ], page: 4),
      };
      final repository = _FakePerformerRequestRepository(pages: pages);
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-wanted',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedPages, <int>[0, 1, 2, 3]);
      expect(
        find.byKey(const Key('continue-filtered-event-request-search')),
        findsOneWidget,
      );

      await _tapRequestControl(
        tester,
        find.byKey(const Key('continue-filtered-event-request-search')),
      );
      await tester.pumpAndSettle();
      expect(repository.requestedPages, <int>[0, 1, 2, 3, 4]);
      expect(find.text('Sahbaz • Grup'), findsOneWidget);
    });

    testWidgets('a stale page cannot overwrite a changed band scope', (
      tester,
    ) async {
      final stale = Completer<Result<EventPerformerRequestPage>>();
      final repository = _FakePerformerRequestRepository(
        listFutures: <Future<Result<EventPerformerRequestPage>>>[
          stale.future,
          Future.value(
            Result.success(
              _page(<EventPerformerRequest>[
                _request(requestId: 'fresh', targetId: 'band-2'),
              ]),
            ),
          ),
        ],
      );
      const screenKey = Key('scoped-requests');
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            key: screenKey,
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-1',
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(repository.listCalls, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: EventPerformerRequestsScreen(
            key: screenKey,
            repository: repository,
            targetType: EventPerformerTargetType.band,
            targetId: 'band-2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sahbaz • Grup'), findsOneWidget);

      stale.complete(
        Result.success(
          _page(<EventPerformerRequest>[
            _request(requestId: 'stale', targetId: 'band-1'),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sahbaz • Grup'), findsOneWidget);
      expect(repository.targetIds, <String?>['band-1', 'band-2']);
    });
  });
}

WeeklyCalendarEvent _pendingCarouselEvent(String id) {
  return WeeklyCalendarEvent(
    id: id,
    title: 'Etkinlik $id',
    artistName: 'Performer',
    artistProfileId: null,
    bandProfileId: null,
    performerType: 'MANUAL',
    venueName: 'Mekan',
    venueId: null,
    city: '-',
    district: '-',
    neighborhood: '-',
    eventDate: '08.09.2026',
    startTime: '21:00',
    endTime: '23:00',
    description: '',
  );
}

WeeklyCalendarEvent _acceptedCarouselEvent(int index) {
  return WeeklyCalendarEvent(
    id: 'cache-event-$index',
    title: 'Etkinlik $index',
    artistName: 'Sanatçı $index',
    artistProfileId: 'cache-musician-$index',
    bandProfileId: null,
    performerType: 'MUSICIAN',
    venueName: 'Mekan',
    venueId: null,
    city: '-',
    district: '-',
    neighborhood: '-',
    eventDate: '08.09.2026',
    startTime: '21:00',
    endTime: '23:00',
    description: '',
  );
}

Widget _eventNavigationApp({
  required WeeklyCalendarEvent event,
  required ValueChanged<RouteSettings> onRoute,
}) {
  return MaterialApp(
    home: WeeklyEventDetailScreen(event: event),
    onGenerateRoute: (settings) {
      onRoute(settings);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('profile destination')),
      );
    },
  );
}

WeeklyCalendarEvent _calendarEvent({
  String? artistProfileId,
  String? bandProfileId,
  String? performerType,
}) {
  return WeeklyCalendarEvent(
    id: 'event-1',
    title: 'Sahbaz Gecesi',
    artistName: 'Sahbaz',
    artistProfileId: artistProfileId,
    bandProfileId: bandProfileId,
    performerType:
        performerType ?? (bandProfileId == null ? 'MUSICIAN' : 'BAND'),
    venueName: 'SoundConnect Ankara',
    venueId: null,
    city: 'Ankara',
    district: 'Çankaya',
    neighborhood: 'Kızılay',
    eventDate: '08.09.2026',
    startTime: '21:00',
    endTime: '23:00',
    description: '',
  );
}

Map<String, dynamic> _requestJson({String requestId = 'request-1'}) {
  return <String, dynamic>{
    'id': requestId,
    'eventId': 'event-$requestId',
    'eventTitle': 'Sahbaz Gecesi',
    'eventDate': '2026-09-08',
    'startTime': '21:00:00',
    'venueId': 'venue-1',
    'venueName': 'SoundConnect Ankara',
    'performerType': 'BAND',
    'bandId': 'band-1',
    'performerName': 'Sahbaz',
    'status': 'PENDING',
  };
}

EventPerformerRequestPage _page(
  List<EventPerformerRequest> items, {
  int page = 0,
  bool hasNext = false,
}) {
  return EventPerformerRequestPage(
    items: items,
    page: page,
    size: 20,
    totalElements: items.length,
    totalPages: hasNext ? page + 2 : (items.isEmpty ? 0 : page + 1),
    hasNext: hasNext,
  );
}

EventPerformerRequest _request({
  String requestId = 'request-1',
  EventPerformerTargetType targetType = EventPerformerTargetType.band,
  String targetId = 'band-1',
  String performerName = 'Sahbaz',
  bool? profileCalendarApproved = false,
  EventPerformerRequestPurpose purpose =
      EventPerformerRequestPurpose.performerConsent,
}) {
  return EventPerformerRequest(
    requestPurpose: purpose,
    requestId: requestId,
    eventId: 'event-$requestId',
    eventTitle: 'Sahbaz Gecesi',
    eventDate: DateTime(2026, 9, 8),
    startTime: '21:00:00',
    endTime: '23:00:00',
    venueId: 'venue-1',
    venueName: 'SoundConnect Ankara',
    venueProfilePictureUrl: null,
    targetType: targetType,
    targetId: targetId,
    musicianProfileId: targetType == EventPerformerTargetType.musician
        ? targetId
        : null,
    bandId: targetType == EventPerformerTargetType.band ? targetId : null,
    performerName: performerName,
    status: EventPerformerRequestStatus.pending,
    profileCalendarApproved: profileCalendarApproved,
    decisionAllowed: true,
    canReconsider: false,
    expired: false,
    serverNow: DateTime.utc(2026, 9, 6),
    eventStartsAt: DateTime.utc(2026, 9, 8, 18),
    createdAt: DateTime(2026, 9, 4),
    decidedAt: null,
  );
}

Future<void> _tapRequestControl(
  WidgetTester tester,
  Finder target, {
  bool warnIfMissed = true,
}) async {
  // Poster-bearing cards may extend past a short viewport. Exercise the same
  // scroll-then-tap behavior as a user without weakening decision assertions.
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: warnIfMissed);
}
