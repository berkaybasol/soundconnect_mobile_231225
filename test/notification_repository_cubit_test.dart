import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/models/app_notification_model.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';

import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

import 'support/event_invitation_navigation_fakes.dart';

part 'notification_repository_cubit_test_cubit.dart';

void main() {
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
      final repository = NotificationRepositoryImpl(apiClient);

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
      );
      final unknownRepository = NotificationRepositoryImpl(
        _NotificationApiClientFake((_, __) => throw StateError('bad payload')),
      );

      final typedResult = await typedRepository.getRecentNotifications();
      final unknownResult = await unknownRepository.getUnreadCount();

      expect(typedResult.error, same(typed));
      expect(unknownResult.error?.code, 'notification_unread_unknown');
    });
  });

  _registerNotificationCubitTests();

  testWidgets('notification target opens before mark-as-read completes', (
    tester,
  ) async {
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
      realtimeClient: realtime,
    );
    addTearDown(() async {
      if (!(repository.markReadRequest?.isCompleted ?? true)) {
        repository.markReadRequest!.complete(const Result.success(null));
      }
      await cubit.close();
      await realtime.closeStreams();
    });
    RouteSettings? pushedSettings;

    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: MaterialApp(
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

    await tester.tap(find.text('collab-pending-read'));
    await tester.pump();

    expect(pushedSettings?.name, AppRoutes.collabDiscovery);
    expect(repository.markReadRequest!.isCompleted, isFalse);
    repository.markReadRequest!.complete(const Result.success(null));
    await tester.pump();
  });

  testWidgets(
    'customer cancellation notification opens the Studio owner calendar',
    (tester) async {
      final notification = _notification(
        'cancelled-by-customer',
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

      expect(pushedSettings?.name, AppRoutes.studioReservationCalendar);
      final args = pushedSettings?.arguments as StudioReservationCalendarArgs;
      expect(args.ownerMode, isTrue);
      expect(args.roomId, 'room-1');
      expect(args.studioProfileId, 'studio-1');
      expect(args.reservationId, 'reservation-1');
      expect(args.reservationDate, DateTime(2026, 8, 3));
    },
  );

  testWidgets(
    'archived-room cancellation opens the Studio profile instead of a dead room',
    (tester) async {
      final notification = _notification(
        'archived-room',
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

      expect(pushedSettings?.name, AppRoutes.studioPublicProfile);
      final args = pushedSettings?.arguments as PublicProfileArgs;
      expect(args.profileId, 'studio-1');
    },
  );

  testWidgets('Collab review notification preserves its deep-link ids', (
    tester,
  ) async {
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
    await tester.tap(find.text('collab-review'));
    await tester.pumpAndSettle();

    expect(pushedSettings?.name, AppRoutes.collabDiscovery);
    final args = pushedSettings?.arguments as CollabDiscoveryRouteArgs;
    expect(args.target, CollabDeepLinkTarget.reviews);
    expect(args.initialListingId, 'listing-1');
    expect(args.jobId, 'job-1');
    expect(args.reviewId, 'review-1');
  });

  testWidgets(
    'ghost DM payload bypasses stale resolver identity and propagates mode',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      final resolver = _RecordingDmProfileResolver(<DmProfileTarget>[
        const DmProfileTarget(
          type: DmProfileTargetType.listener,
          id: 'listener-profile-1',
          displayName: 'stale-standard-name',
          imageUrl: 'https://stale.example/avatar.jpg',
        ),
      ]);
      serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
      final notification = _notification(
        'ghost-dm',
        type: 'DM_MESSAGE',
        payload: const <String, dynamic>{
          'module': 'DM',
          'conversationId': 'conversation-1',
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

      expect(
        find.byKey(const ValueKey('notification-ghost-badge-ghost-dm')),
        findsOneWidget,
      );

      await tester.tap(find.text('ghost-dm'));
      await tester.pumpAndSettle();

      expect(resolver.calls, 0);
      expect(pushedSettings?.name, AppRoutes.dmChat);
      final args = pushedSettings?.arguments as DmChatScreenArgs;
      expect(args.conversationId, 'conversation-1');
      expect(args.otherUserId, 'listener-user-1');
      expect(args.otherUsername, 'payload-ghost-name');
      expect(args.otherUserProfilePicture, isNull);
      expect(args.otherUserVisibilityMode, ListenerVisibilityMode.ghost);
    },
  );

  testWidgets(
    'ghost follower sheet uses sanitized identity and shows ghost badge',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
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

      expect(
        find.byKey(const ValueKey('notification-ghost-badge-ghost-follower')),
        findsOneWidget,
      );

      await tester.tap(find.text('ghost-follower'));
      await tester.pumpAndSettle();

      expect(resolver.calls, 1);
      expect(find.text('payload-ghost-name'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('social-target-ghost-badge-listener-profile-1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('payload-ghost-name'));
      await tester.pumpAndSettle();

      expect(pushedSettings?.name, AppRoutes.listenerPublicProfile);
      final args = pushedSettings?.arguments as PublicProfileArgs;
      expect(args.profileId, 'listener-profile-1');
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

      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: const MaterialApp(home: NotificationScreen()),
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
        find.text('Davetin ait olduğu profil doğrulanamadı.'),
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

Future<InvitationRequests> _openApprovalNotification(
  WidgetTester tester,
  Map<String, dynamic> target, {
  bool personalVisible = true,
  bool bandVisible = true,
}) async {
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  _registerInvitationAccess(
    personalVisible: personalVisible,
    bandVisible: bandVisible,
  );
  final invitations = InvitationRequests();
  serviceLocator.registerSingleton<EventPerformerRequestRepository>(
    invitations,
  );
  final repository = _NotificationRepositoryFake(
    pages: {
      0: Result.success(
        pagination.Page<AppNotification>(
          items: [
            _notification(
              'scoped-invitation',
              type: 'EVENT_PERFORMER_APPROVAL_REQUESTED',
              payload: {
                'module': 'EVENT_PERFORMER',
                'action': 'APPROVAL_REQUESTED',
                ...target,
              },
            ),
          ],
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
  await tester.pumpWidget(
    BlocProvider<NotificationCubit>.value(
      value: cubit,
      child: const MaterialApp(home: NotificationScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('scoped-invitation'));
  await tester.pumpAndSettle();
  return invitations;
}

void _registerInvitationAccess({
  bool personalVisible = true,
  bool bandVisible = true,
}) {
  final session = InvitationSession();
  final personal = InvitationCalendar(visible: personalVisible);
  final band = InvitationCalendar(visible: bandVisible);
  serviceLocator.registerSingleton<AuthSessionManager>(session);
  serviceLocator.registerSingleton<MusicianProfileRepository>(
    InvitationProfileRepository(),
  );
  serviceLocator.registerSingleton<BandRepository>(InvitationBands());
  serviceLocator.registerSingleton<MusicianCalendarRepository>(personal);
  serviceLocator.registerSingleton<BandCalendarRepositoryFactory>(
    InvitationBandCalendars(band),
  );
  addTearDown(() async {
    session.dispose();
    await personal.dispose();
    await band.dispose();
  });
}

Future<WeeklyCalendarEvent> _openPerformerEventNotification(
  WidgetTester tester, {
  required String type,
  required String action,
  required VenueEventDetail detail,
}) async {
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  serviceLocator.registerSingleton<VenueEventRepository>(
    _PerformerNotificationVenueEventRepository(detail),
  );
  serviceLocator.registerSingleton<EngagementRepository>(
    _PerformerNotificationEngagementRepository(),
  );
  serviceLocator.registerSingleton<MusicianProfileRepository>(
    _PerformerNotificationMusicianRepository(),
  );

  final notification = _notification(
    'event-performer-${type.toLowerCase()}',
    type: type,
    payload: <String, dynamic>{
      'module': 'EVENT_PERFORMER',
      'action': action,
      'eventId': detail.id,
      'musicianProfileId': 'musician-stale',
      'bandId': 'band-stale',
      'performerName': 'Eski Sanatçı',
      'venueId': 'stale-unapproved-venue',
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

  await tester.pumpWidget(
    BlocProvider<NotificationCubit>.value(
      value: cubit,
      child: const MaterialApp(home: NotificationScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(notification.title));
  await tester.pumpAndSettle();

  return tester
      .widget<WeeklyEventDetailScreen>(find.byType(WeeklyEventDetailScreen))
      .event;
}

AppNotification _notification(
  String id, {
  String recipientId = 'user-1',
  String type = 'GENERAL',
  bool read = false,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return AppNotification(
    id: id,
    recipientId: recipientId,
    type: type,
    title: id,
    message: 'Message',
    read: read,
    createdAt: null,
    payload: payload,
  );
}

class _NotificationApiClientFake extends ApiClient {
  _NotificationApiClientFake(this.handler);

  final Future<Object?> Function(String path, Map<String, dynamic>? query)
  handler;
  Map<String, dynamic>? lastQuery;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    lastQuery = query;
    final payload = await handler(path, query);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}

class _RecordingDmProfileResolver implements DmUserProfileResolver {
  _RecordingDmProfileResolver(this.targets);

  final List<DmProfileTarget> targets;
  int calls = 0;

  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    calls += 1;
    return targets;
  }
}

class _NotificationRepositoryFake implements NotificationRepository {
  _NotificationRepositoryFake({
    required this.pages,
    this.unread = const Result.success(0),
  });

  final Map<int, Result<pagination.Page<AppNotification>>> pages;
  final Result<int> unread;
  final List<int> requestedPages = <int>[];
  Result<void> deleteResult = const Result.success(null);
  Completer<Result<void>>? markReadRequest;

  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return pages[page] ??
        const Result.success(
          pagination.Page<AppNotification>(items: [], hasNext: false),
        );
  }

  @override
  Future<Result<int>> getUnreadCount() async => unread;

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => deleteResult;

  @override
  Future<Result<int>> clearAllNotifications() async => const Result.success(0);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> markAllAsRead() async => const Result.success(0);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    return markReadRequest?.future ?? const Result.success(null);
  }
}

class _EmptyEventPerformerRequestRepository
    implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError(
    'Unexpected reconsideration in notification test.',
  );

  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async => Result.success(
    EventPerformerRequestPage(
      items: const <EventPerformerRequest>[],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    ),
  );

  @override
  Future<Result<void>> accept(
    String requestId, {
    bool showOnProfile = false,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> reject(String requestId) async =>
      const Result.success(null);
}

class _PerformerNotificationVenueEventRepository
    implements VenueEventRepository {
  final VenueEventDetail detail;

  _PerformerNotificationVenueEventRepository(this.detail);

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      Result.success(detail);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PerformerNotificationEngagementRepository
    implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PerformerNotificationMusicianRepository
    implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async => const Result.failure(
    AppError(
      code: 'not_needed',
      message: 'Profile rendering is not under test.',
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledNotificationRepository implements NotificationRepository {
  final List<Completer<Result<pagination.Page<AppNotification>>>> listRequests =
      <Completer<Result<pagination.Page<AppNotification>>>>[];
  Result<int> unreadResult = const Result.success(0);
  Completer<Result<int>>? unreadRequest;
  int unreadCalls = 0;
  Completer<Result<int>>? markAllRequest;
  Completer<Result<int>>? clearAllRequest;

  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) {
    final request = Completer<Result<pagination.Page<AppNotification>>>();
    listRequests.add(request);
    return request.future;
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    unreadCalls += 1;
    return unreadRequest?.future ?? unreadResult;
  }

  @override
  Future<Result<int>> clearAllNotifications() async =>
      clearAllRequest?.future ?? const Result.success(0);

  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => const Result.success(null);

  @override
  Future<Result<List<AppNotification>>> getRecentNotifications() async =>
      const Result.success(<AppNotification>[]);

  @override
  Future<Result<int>> markAllAsRead() async =>
      markAllRequest?.future ?? const Result.success(0);

  @override
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      const Result.success(null);
}

class _TestNotificationRealtimeClient extends NotificationRealtimeClient {
  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<int> _badgeController =
      StreamController<int>.broadcast();
  final StreamController<void> _connectionController =
      StreamController<void>.broadcast();
  bool _connected = false;

  @override
  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;

  @override
  Stream<int> get badgeStream => _badgeController.stream;

  @override
  Stream<void> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  void retain() {}

  @override
  Future<void> release() async {}

  @override
  Future<void> connect({required String userId, required String token}) async {
    _connected = true;
    _connectionController.add(null);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  void emitNotification(AppNotification notification) {
    _notificationController.add(notification);
  }

  void emitBadge(int count) {
    _badgeController.add(count);
  }

  Future<void> closeStreams() async {
    await super.dispose();
    await _notificationController.close();
    await _badgeController.close();
    await _connectionController.close();
  }
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async => value = token;
}

String _jwt(String subject) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const <String, dynamic>{'alg': 'none'})}.'
      '${encode(<String, dynamic>{'sub': subject})}.signature';
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(predicate(), isTrue);
}
