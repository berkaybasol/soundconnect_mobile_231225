import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/models/app_notification_model.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/studio_reservation_notification_target.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/studio_reservation_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';

import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

import 'support/event_invitation_navigation_fakes.dart';
import 'support/event_audience_fakes.dart';
import 'support/studio_notification_product_fakes.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';

part 'notification_repository_cubit_test_cubit.dart';
part 'notification_repository_cubit_test_confirmed_read.dart';

part 'notification_repository_cubit_test_notification_test_route.dart';

const _dmUser = '70000000-0000-4000-8000-000000000001';

const _dmNotice = '50000000-0000-4000-8000-000000000001';

const _dmConversation = '60000000-0000-4000-8000-000000000001';

const _studioNotice = '80000000-0000-4000-8000-000000000001';

void main() {
  testWidgets(
    'late event notification detail cannot open after account switch',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      final sessions = AudienceTestSessions(
        audienceSession(user: 'user-1', role: 'ROLE_VENUE'),
      );
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      addTearDown(sessions.dispose);
      final detail = Completer<Result<VenueEventDetail>>();
      final events = _DeferredEventRepository(detail);
      serviceLocator.registerSingleton<VenueEventRepository>(events);
      serviceLocator.registerSingleton<EngagementRepository>(
        _PerformerNotificationEngagementRepository(),
      );
      serviceLocator.registerSingleton<MusicianProfileRepository>(
        _PerformerNotificationMusicianRepository(),
      );
      final item = _notification(
        'delayed-event',
        type: 'EVENT_PERFORMER_APPROVED',
        payload: const {
          'module': 'EVENT_PERFORMER',
          'action': 'APPROVED',
          'eventId': 'event-1',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: {
          0: Result.success(pagination.Page(items: [item], hasNext: false)),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      _registerFreshNotificationTarget(cubit, item);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            navigatorObservers: [notificationTargetRouteObserver],
            home: const NotificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('delayed-event'));
      await tester.pump();
      await tester.pump();
      expect(events.reads, 1);
      sessions.replace(
        audienceSession(
          user: 'replacement',
          token: 'new-token',
          role: 'ROLE_VENUE',
        ),
      );
      detail.complete(
        const Result.success(
          VenueEventDetail(
            id: 'event-1',
            shareUrl: null,
            posterImage: null,
            performerName: 'Fixture',
            musicianProfileId: null,
            title: 'Old account event',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventDetailScreen), findsNothing);
    },
  );

  test(
    'Collab notification actions select the intended management surface',
    () {
      CollabDiscoveryRouteArgs args(
        String action, {
        String? applicationId,
        String? jobId,
      }) => CollabDiscoveryRouteArgs.fromNotificationPayload(<String, dynamic>{
        'action': action,
        'listingId': 'listing-1',
        if (applicationId != null) 'applicationId': applicationId,
        if (jobId != null) 'jobId': jobId,
      });

      expect(
        args('APPLICATION_RECEIVED', applicationId: 'application-1').target,
        CollabDeepLinkTarget.incomingApplications,
      );
      expect(
        args('APPLICATION_REJECTED', applicationId: 'application-1').target,
        CollabDeepLinkTarget.myApplications,
      );
      expect(
        args('APPLICATION_ACCEPTED', jobId: 'job-1').target,
        CollabDeepLinkTarget.jobs,
      );
      expect(
        args('JOB_COMPLETION_REQUESTED', jobId: 'job-1').target,
        CollabDeepLinkTarget.jobs,
      );
      expect(args('REPORT_RESOLVED').target, CollabDeepLinkTarget.discovery);
    },
  );

  group('AppNotificationModel', () {
    test('parses values and safely converts loosely typed payload maps', () {
      final model = AppNotificationModel.fromJson(<String, dynamic>{
        'id': 9,
        'recipientId': 'user-1',
        'type': 'DM_MESSAGE',
        'message': 'Hello',
        'read': true,
        'createdAt': '2026-07-13T11:30:00Z',
        'payload': <Object?, Object?>{'conversationId': 12},
      });

      expect(model.id, '9');
      expect(model.title, 'Bildirim');
      expect(model.read, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 7, 13, 11, 30));
      expect(model.payload, <String, dynamic>{'conversationId': 12});
    });

    test('uses safe defaults for malformed dates and payloads', () {
      final model = AppNotificationModel.fromJson(<String, dynamic>{
        'read': 'true',
        'createdAt': 'bad-date',
        'payload': <Object?>[],
      });

      expect(model.read, isFalse);
      expect(model.createdAt, isNull);
      expect(model.payload, isEmpty);
    });
  });

  group('NotificationRepositoryImpl', () {
    late AudienceTestSessions repositorySessions;
    setUp(() {
      repositorySessions = AudienceTestSessions(
        audienceSession(user: 'user-1', role: 'ROLE_MUSICIAN'),
      );
    });
    tearDown(() => repositorySessions.dispose());
    test('decodes a page and sends stable pagination and sort query', () async {
      final apiClient = _NotificationApiClientFake((path, query) async {
        expect(path, NotificationEndpoints.list);
        return <String, dynamic>{
          'number': 3,
          'last': false,
          'content': <Object?>[
            <String, dynamic>{'id': 'n-1', 'title': 'One'},
            'ignored',
          ],
        };
      });
      final repository = NotificationRepositoryImpl(
        apiClient,
        repositorySessions,
      );

      final result = await repository.listNotifications(page: 3, size: 7);

      expect(result.data?.items.single.id, 'n-1');
      expect(result.data?.hasNext, isTrue);
      expect(result.data?.nextCursor, '4');
      expect(apiClient.lastQuery, <String, dynamic>{
        'page': 3,
        'size': 7,
        'sort': 'createdAt,desc',
      });
    });

    test(
      'decodes numeric counters and missing counter values as zero',
      () async {
        var call = 0;
        final repository = NotificationRepositoryImpl(
          _NotificationApiClientFake((_, __) async {
            call += 1;
            return call == 1
                ? <String, dynamic>{'unread': 8.9}
                : <String, dynamic>{};
          }),
          repositorySessions,
        );

        final first = await repository.getUnreadCount();
        final second = await repository.getUnreadCount();

        expect(first.data, 8);
        expect(second.data, 0);
      },
    );

    test('preserves typed errors and maps unexpected failures', () async {
      const typed = AppError(code: '401', message: 'Unauthorized');
      final typedRepository = NotificationRepositoryImpl(
        _NotificationApiClientFake((_, __) => throw ApiException(typed)),
        repositorySessions,
      );
      final unknownRepository = NotificationRepositoryImpl(
        _NotificationApiClientFake((_, __) => throw StateError('bad payload')),
        repositorySessions,
      );

      final typedResult = await typedRepository.getRecentNotifications();
      final unknownResult = await unknownRepository.getUnreadCount();

      expect(typedResult.error, same(typed));
      expect(unknownResult.error?.code, 'notification_unread_unknown');
    });
  });

  _registerNotificationCubitTests();

  testWidgets(
    'unresolved Collab notification stays on inbox without prematurely reading',
    (tester) async {
      final sessions = await _registerTapSession();
      final notification = _notification(
        'collab-pending-read',
        type: 'COLLAB_APPLICATION_RECEIVED',
        payload: const <String, dynamic>{
          'module': 'COLLAB',
          'action': 'APPLICATION_RECEIVED',
          'listingId': 'listing-1',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      )..markReadRequest = Completer<Result<void>>();
      final realtime = _TestNotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        sessions: sessions,
        realtimeClient: realtime,
      );
      addTearDown(() async {
        if (!(repository.markReadRequest?.isCompleted ?? true)) {
          repository.markReadRequest!.complete(const Result.success(null));
        }
        await cubit.close();
        await realtime.closeStreams();
      });
      final lookup = Completer<Result<AppNotification>>();
      serviceLocator.registerSingleton<NotificationTargetRepository>(
        _FreshNotificationTarget(notification, lookup: lookup),
      );
      serviceLocator.registerSingleton<NotificationCubit>(cubit);
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorObservers: [notificationTargetRouteObserver],
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = _notificationRouteSettings(settings);
              return _notificationTestRoute(settings, ready: true);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('collab-pending-read'));
      await tester.pumpAndSettle();

      expect(pushedSettings, isNull);
      expect(repository.markReadRequest!.isCompleted, isFalse);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
      expect(cubit.state.items.single.read, isFalse);
      expect(find.byType(NotificationScreen), findsOneWidget);
      lookup.complete(
        const Result.failure(NotificationTargetRepository.unavailable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(repository.markReadIds, isEmpty);
    },
  );

  testWidgets(
    'customer cancellation resolves the exact current Studio owner reservation',
    (tester) async {
      final sessions = await _registerTapSession(
        user: _dmUser,
        role: 'ROLE_STUDIO',
      );
      final targets = _StudioTargetRepository();
      serviceLocator.registerSingleton<NotificationTargetRepository>(targets);
      final rooms = StudioTargetRooms();
      serviceLocator.registerSingleton<StudioRoomRepository>(rooms);
      final notification = _notification(
        _studioNotice,
        title: 'cancelled-by-customer',
        recipientId: _dmUser,
        type: 'STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER',
        payload: <String, dynamic>{
          'module': 'STUDIO',
          'action': 'CANCELLED_BY_CUSTOMER',
          'roomId': 'room-1',
          'studioProfileId': 'studio-1',
          'reservationId': 'reservation-1',
          'localDate': '2026-08-03',
          'zoneId': 'Europe/Istanbul',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        sessions: sessions,
        realtimeClient: realtime,
      );
      serviceLocator.registerSingleton<NotificationCubit>(cubit);
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorObservers: [notificationTargetRouteObserver],
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancelled-by-customer'));
      await tester.pumpAndSettle();

      expect(
        find.byType(StudioReservationNotificationOpenScreen),
        findsNothing,
      );
      expect(find.byType(StudioReservationCalendarScreen), findsOneWidget);
      final calendar = tester.widget<StudioReservationCalendarScreen>(
        find.byType(StudioReservationCalendarScreen),
      );
      expect(calendar.args.roomId, studioTargetRoomId);
      expect(calendar.args.studioProfileId, studioTargetProfileId);
      expect(calendar.args.reservationId, studioTargetReservationId);
      expect(calendar.args.reservationDate, DateTime(2026, 9, 28));
      expect(calendar.args.ownerMode, isTrue);
      expect(pushedSettings, isNull);
      expect(targets.lookups.single.notificationId, notification.id);
      expect(targets.lookups.single.recipientId, sessions.session.userId);
      expect(targets.lookups.single.type, notification.type);
      expect(find.text('Current verified room'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('studio-reservation-$studioTargetReservationId'),
        ),
        findsOneWidget,
      );
      expect(find.text('Seçili rezervasyon'), findsOneWidget);
      expect(
        find.text('Rezervasyon müşteri tarafından iptal edildi.'),
        findsOneWidget,
      );
      expect(rooms.roomIds, [studioTargetRoomId]);
      expect(rooms.ownerDates, contains(DateTime(2026, 9, 28)));
      expect(targets.ackIds, [notification.id]);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
      expect(cubit.state.items.single.read, isTrue);
      Navigator.of(
        tester.element(find.byType(StudioReservationCalendarScreen)),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(NotificationScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'archived-room cancellation stays unread on lookup failure then opens real studio profile',
    (tester) async {
      final sessions = await _registerTapSession(user: _dmUser);
      final targets = _StudioTargetRepository(archived: true)
        ..failLookup = true;
      serviceLocator.registerSingleton<NotificationTargetRepository>(targets);
      final profiles = registerStudioTargetProfileSurface();
      final notification = _notification(
        _studioNotice,
        title: 'archived-room',
        recipientId: _dmUser,
        type: 'STUDIO_RESERVATION_CANCELLED_BY_STUDIO',
        payload: <String, dynamic>{
          'module': 'STUDIO',
          'action': 'CANCELLED_BY_STUDIO_ROOM_ARCHIVED',
          'roomId': 'archived-room-1',
          'studioProfileId': 'studio-1',
          'reservationId': 'reservation-1',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        sessions: sessions,
        realtimeClient: realtime,
      );
      serviceLocator.registerSingleton<NotificationCubit>(cubit);
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorObservers: [notificationTargetRouteObserver],
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('archived-room'));
      await tester.pumpAndSettle();

      expect(
        find.byType(StudioReservationNotificationOpenScreen),
        findsNothing,
      );
      expect(
        find.byType(
          StudioReservationNotificationOpenScreen,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(NotificationScreen))).canPop(),
        isFalse,
      );
      expect(pushedSettings, isNull);
      expect(find.text('Bu rezervasyon şu anda açılamıyor.'), findsOneWidget);
      expect(targets.ackIds, isEmpty);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
      expect(cubit.state.items.single.read, isFalse);
      targets.failLookup = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(targets.lookups, hasLength(2));
      expect(
        targets.lookups.every(
          (target) => target.notificationId == notification.id,
        ),
        isTrue,
      );
      expect(find.byType(StudioPublicProfileScreen), findsOneWidget);
      expect(
        find.byType(
          StudioReservationNotificationOpenScreen,
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(find.text('Current verified studio'), findsOneWidget);
      expect(profiles.gets, 1);
      expect(profiles.profileIds, [studioTargetProfileId]);
      expect(find.text('Rezervasyonun odası arşivlendi.'), findsOneWidget);
      expect(targets.ackIds, [notification.id]);
      expect(cubit.state.items.single.read, isTrue);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
      Navigator.of(
        tester.element(find.byType(StudioPublicProfileScreen)),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(NotificationScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'unverified Collab review payload does not open discovery or mark read',
    (tester) async {
      await _registerTapSession();
      final notification = _notification(
        'collab-review',
        type: 'COLLAB_REVIEW_RECEIVED',
        payload: <String, dynamic>{
          'module': 'COLLAB',
          'action': 'REVIEW_RECEIVED',
          'listingId': 'listing-1',
          'jobId': 'job-1',
          'reviewId': 'review-1',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = _notificationRouteSettings(settings);
              return _notificationTestRoute(settings);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('collab-review'));
      await tester.pumpAndSettle();

      expect(pushedSettings, isNull);
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
    },
  );

  testWidgets(
    'ghost DM uses authoritative conversation identity instead of payload or resolver snapshots',
    (tester) async {
      await _registerTapSession(user: _dmUser, role: 'ROLE_LISTENER');
      final resolver = _RecordingDmProfileResolver(<DmProfileTarget>[
        const DmProfileTarget(
          type: DmProfileTargetType.listener,
          id: 'listener-profile-1',
          displayName: 'stale-standard-name',
          imageUrl: 'https://stale.example/avatar.jpg',
        ),
      ]);
      serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
      final dm = _DmPreviewRepository();
      serviceLocator.registerSingleton<DmRepository>(dm);
      final notification = _notification(
        _dmNotice,
        title: 'ghost-dm',
        recipientId: _dmUser,
        type: 'DM_NEW_MESSAGE',
        payload: const <String, dynamic>{
          'module': 'DM',
          'conversationId': _dmConversation,
          'senderId': 'listener-user-1',
          'senderUsername': 'payload-ghost-name',
          'senderVisibilityMode': 'GHOST',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = _notificationRouteSettings(settings);
              return _notificationTestRoute(settings);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('notification-ghost-badge-$_dmNotice')),
        findsOneWidget,
      );

      await tester.tap(find.text('ghost-dm'));
      await tester.pumpAndSettle();

      expect(resolver.calls, 0);
      expect(dm.reads, [_dmConversation]);
      expect(pushedSettings?.name, AppRoutes.dmChat);
      final args = pushedSettings?.arguments as DmChatScreenArgs;
      expect(args.conversationId, _dmConversation);
      expect(args.otherUserId, 'verified-listener-user');
      expect(args.otherUsername, 'current-public-ghost-name');
      expect(args.otherUserProfilePicture, isNull);
      expect(args.otherUserVisibilityMode, ListenerVisibilityMode.ghost);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
      expect(cubit.state.items.single.read, isFalse);
    },
  );

  testWidgets(
    'unverified ghost follower keeps badge but never trusts payload identity',
    (tester) async {
      await _registerTapSession();
      final resolver = _RecordingDmProfileResolver(<DmProfileTarget>[
        const DmProfileTarget(
          type: DmProfileTargetType.listener,
          id: 'listener-profile-1',
          displayName: 'stale-standard-name',
          imageUrl: null,
        ),
        const DmProfileTarget(
          type: DmProfileTargetType.venue,
          id: 'venue-profile-1',
          displayName: 'Venue profile',
          imageUrl: null,
        ),
      ]);
      serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
      final notification = _notification(
        'ghost-follower',
        type: 'SOCIAL_NEW_FOLLOWER',
        payload: const <String, dynamic>{
          'module': 'SOCIAL',
          'action': 'NEW_FOLLOWER',
          'followerId': 'listener-user-1',
          'followerUsername': 'payload-ghost-name',
          'followerVisibilityMode': 'GHOST',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });
      RouteSettings? pushedSettings;

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: const NotificationScreen(),
            onGenerateRoute: (settings) {
              pushedSettings = _notificationRouteSettings(settings);
              return _notificationTestRoute(settings);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('notification-ghost-badge-ghost-follower')),
        findsOneWidget,
      );

      await tester.tap(find.text('ghost-follower'));
      await tester.pumpAndSettle();

      expect(resolver.calls, 0);
      expect(find.text('payload-ghost-name'), findsNothing);
      expect(pushedSettings, isNull);
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(repository.markReadIds, isEmpty);
      expect(repository.markAllCalls, 0);
    },
  );

  testWidgets(
    'legacy approval notification resolves personal scope independently of calendar',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      _registerInvitationAccess();
      serviceLocator.registerSingleton<EventPerformerRequestRepository>(
        _EmptyEventPerformerRequestRepository(),
      );
      final notification = _notification(
        'event-performer-request',
        recipientId: 'owner-1',
        type: 'EVENT_PERFORMER_APPROVAL_REQUESTED',
        payload: const <String, dynamic>{
          'module': 'EVENT_PERFORMER',
          'action': 'APPROVAL_REQUESTED',
          'requestId': 'request-1',
          'eventId': 'event-1',
        },
      );
      final repository = _NotificationRepositoryFake(
        pages: <int, Result<pagination.Page<AppNotification>>>{
          0: Result.success(
            pagination.Page<AppNotification>(
              items: <AppNotification>[notification],
              hasNext: false,
            ),
          ),
        },
      );
      final realtime = NotificationRealtimeClient();
      final cubit = NotificationCubit(
        repository,
        _MemoryTokenStore(),
        realtimeClient: realtime,
      );
      addTearDown(() async {
        await cubit.close();
        await realtime.dispose();
      });

      _registerFreshNotificationTarget(cubit, notification);
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorObservers: [notificationTargetRouteObserver],
            home: const NotificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('event-performer-request'));
      await tester.pumpAndSettle();

      expect(find.text('Etkinlik Davetleri'), findsOneWidget);
      expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
    },
  );

  testWidgets(
    'approved performer notification trusts fresh detail instead of stale payload ids',
    (tester) async {
      final event = await _openPerformerEventNotification(
        tester,
        type: 'EVENT_PERFORMER_APPROVED',
        action: 'APPROVED',
        detail: const VenueEventDetail(
          id: 'event-1',
          shareUrl: null,
          posterImage: null,
          performerName: 'Güncel Sanatçı',
          musicianProfileId: 'musician-fresh',
          bandId: null,
          performerType: 'MUSICIAN',
          title: 'Güncel Etkinlik',
          venueId: null,
        ),
      );

      expect(event.artistProfileId, 'musician-fresh');
      expect(event.bandProfileId, isNull);
    },
  );

  testWidgets(
    'rejected performer notification never revives stale payload profile ids',
    (tester) async {
      final event = await _openPerformerEventNotification(
        tester,
        type: 'EVENT_PERFORMER_REJECTED',
        action: 'REJECTED',
        detail: const VenueEventDetail(
          id: 'event-1',
          shareUrl: null,
          posterImage: null,
          performerName: 'Sahbaz',
          musicianProfileId: null,
          bandId: null,
          performerType: 'MANUAL',
          title: 'Güncel Etkinlik',
          venueId: null,
        ),
      );

      expect(event.artistProfileId, isNull);
      expect(event.bandProfileId, isNull);
      expect(event.hasLinkedPerformerProfile, isFalse);
    },
  );

  for (final description in <String?>[
    null,
    '   ',
    '  Kapılar 19.30’da açılır.  ',
    'MANUAL performansı',
  ]) {
    testWidgets(
      'event notification uses only authored description: $description',
      (tester) async {
        final event = await _openPerformerEventNotification(
          tester,
          type: 'EVENT_PERFORMER_APPROVED',
          action: 'APPROVED',
          detail: VenueEventDetail(
            id: 'event-1',
            shareUrl: null,
            posterImage: null,
            performerName: 'Sanatçı',
            musicianProfileId: null,
            performerType: 'MANUAL',
            title: 'Güncel Etkinlik',
            description: description,
          ),
        );

        expect(event.description, description?.trim() ?? '');
        expect(event.description, isNot('Message'));
      },
    );
  }

  for (final scope in [
    (
      type: 'MUSICIAN',
      field: 'musicianProfileId',
      id: 'musician-1',
      target: EventPerformerTargetType.musician,
    ),
    (
      type: 'BAND',
      field: 'bandId',
      id: 'band-1',
      target: EventPerformerTargetType.band,
    ),
  ]) {
    testWidgets(
      '${scope.type} OFF notification opens the exact invitation inbox',
      (tester) async {
        final requests = await _openApprovalNotification(
          tester,
          {'performerType': scope.type, scope.field: scope.id},
          personalVisible: scope.target == EventPerformerTargetType.band,
          bandVisible: scope.target == EventPerformerTargetType.musician,
        );
        expect(
          find.byKey(const Key('event-invitations-calendar-disabled')),
          findsNothing,
        );
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(requests.reads, 1);
        expect(requests.targetType, scope.target);
        expect(requests.targetId, scope.id);
      },
    );
    testWidgets(
      '${scope.type} approval notification preserves exact performer target',
      (tester) async {
        await _openApprovalNotification(tester, {
          'performerType': scope.type,
          scope.field: scope.id,
        });
        final screen = tester.widget<EventPerformerRequestsScreen>(
          find.byType(EventPerformerRequestsScreen),
        );
        expect(screen.targetType, scope.target);
        expect(screen.targetId, scope.id);
        expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
      },
    );
  }
  for (final payload in <Map<String, dynamic>>[
    {
      'performerType': 'BAND',
      'bandId': 'band-1',
      'musicianProfileId': 'musician-1',
    },
    {'performerType': 'BAND', 'bandId': 'band-1', 'targetType': 'MUSICIAN'},
    {'performerType': 'BAND'},
    {'performerType': 'MUSICIAN', 'musicianProfileId': 123},
    {'performerType': 'BAND', 'bandId': 'band-1', 'targetId': 'band-other'},
  ]) {
    testWidgets('contradictory invitation payload is not routed: $payload', (
      tester,
    ) async {
      await _openApprovalNotification(tester, payload);
      expect(find.byType(EventPerformerRequestsScreen), findsNothing);
      expect(
        find.text(NotificationTargetRepository.unavailable.message),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'approved notification fails closed when fresh detail ids contradict its type',
    (tester) async {
      final event = await _openPerformerEventNotification(
        tester,
        type: 'EVENT_PERFORMER_APPROVED',
        action: 'APPROVED',
        detail: const VenueEventDetail(
          id: 'event-1',
          shareUrl: null,
          posterImage: null,
          performerName: 'Sahbaz',
          musicianProfileId: 'musician-fresh',
          bandId: 'band-fresh',
          performerType: 'BAND',
          title: 'Güncel Etkinlik',
          venueId: null,
        ),
      );

      expect(event.artistProfileId, isNull);
      expect(event.bandProfileId, isNull);
      expect(event.hasLinkedPerformerProfile, isFalse);
    },
  );
}

Future<AudienceTestSessions> _registerTapSession({
  String user = 'user-1',
  String role = 'ROLE_MUSICIAN',
}) async {
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  final sessions = AudienceTestSessions(
    audienceSession(user: user, role: role),
  );
  serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  addTearDown(sessions.dispose);
  return sessions;
}

RouteSettings _notificationRouteSettings(RouteSettings settings) {
  final arguments = settings.arguments;
  return arguments is NotificationReadArguments
      ? RouteSettings(name: settings.name, arguments: arguments.arguments)
      : settings;
}
