import 'dart:async';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'support/event_audience_fakes.dart';
import 'support/event_invitation_navigation_fakes.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/artist_venue_connection_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/artist_venue_connection_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'support/recording_api_client.dart';

void main() {
  late _Repository repository;
  late NotificationCubit cubit;
  late NotificationRealtimeClient realtime;

  setUp(() {
    repository = _Repository();
    realtime = NotificationRealtimeClient();
    cubit = NotificationCubit(repository, _Tokens(), realtimeClient: realtime);
  });
  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
  });

  testWidgets('opening inbox refreshes without reading any notification', (
    tester,
  ) async {
    repository.items = [_notification(), _notification(id: 'second')];
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.markAllCalls, 0);
    expect(cubit.state.items, hasLength(2));
    expect(cubit.state.items.every((item) => !item.read), isTrue);
    expect(cubit.state.unreadCount, 2);
    // Rebuilds and refreshes must not silently read later arrivals.
    repository.items.add(_notification(id: 'later'));
    await cubit.refresh();
    await tester.pumpAndSettle();
    expect(repository.markAllCalls, 0);
    expect(cubit.state.unreadCount, 3);
    expect(
      cubit.state.items.firstWhere((item) => item.id == 'later').read,
      isFalse,
    );
  });

  testWidgets('failed read-all still loads inbox and preserves unread state', (
    tester,
  ) async {
    repository.failMarkAll = true;
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.markAllCalls, 0);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümünü oku'));
    await tester.pumpAndSettle();
    expect(repository.markAllCalls, 1);
    expect(cubit.state.items.single.read, isFalse);
    expect(cubit.state.unreadCount, 1);
    expect(find.text('Read failed'), findsOneWidget);
  });

  test(
    'old refresh cannot restore unread after an acknowledged read',
    () async {
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      await cubit.markAsRead(cubit.state.items.single);
      repository.pendingPage!.complete(_page([_notification()]));
      await refresh;
      expect(cubit.state.items.single.read, isTrue);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test('old refresh cannot restore a locally read DM notification', () async {
    repository.items = [
      _notification(
        payload: {'module': 'DM', 'conversationId': 'conversation'},
      ),
    ];
    await cubit.refresh();
    repository.pendingPage =
        Completer<Result<pagination.Page<AppNotification>>>();
    final refresh = cubit.refresh();
    cubit.markDmConversationAsReadLocally('conversation');
    repository.pendingPage!.complete(_page(repository.items));
    await refresh;
    expect(cubit.state.items.single.read, isTrue);
    expect(cubit.state.unreadCount, 0);
  });

  test(
    'DM ACK only projects its own message and survives an older refresh',
    () async {
      repository.items = [
        _notification(
          id: 'dm-one',
          type: 'DM_NEW_MESSAGE',
          payload: {'messageId': 'one', 'conversationId': 'same'},
        ),
        _notification(
          id: 'dm-two',
          type: 'DM_NEW_MESSAGE',
          payload: {'messageId': 'two', 'conversationId': 'same'},
        ),
      ];
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      final stalePage = _page(repository.items.toList());
      // Preserve the older page while the successful DM transaction commits
      // the notification read before invoking the product callback.
      repository.items[0] = repository.items[0].copyWith(read: true);
      await cubit.markDmMessageAsReadLocally('one');
      repository.pendingPage!.complete(stalePage);
      await refresh;
      expect(
        cubit.state.items.singleWhere((item) => item.id == 'dm-one').read,
        isTrue,
      );
      expect(
        cubit.state.items.singleWhere((item) => item.id == 'dm-two').read,
        isFalse,
      );
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'read acknowledgement during refresh preserves server notification order',
    () async {
      repository.items = [
        _notification(id: 'newest'),
        _notification(id: 'older'),
      ];
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      await cubit.markAsRead(cubit.state.items.last);
      repository.pendingPage!.complete(_page(repository.items));
      await refresh;
      expect(cubit.state.items.map((item) => item.id), ['newest', 'older']);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.items.last.read, isTrue);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'old refresh cannot resurrect a successfully deleted notification',
    () async {
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      await cubit.deleteNotification(cubit.state.items.single);
      repository.pendingPage!.complete(_page([_notification()]));
      await refresh;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test('shifted pagination cannot reinsert a pending deletion', () async {
    await cubit.refresh();
    repository.pendingPage =
        Completer<Result<pagination.Page<AppNotification>>>();
    repository.pendingDeletion = Completer<Result<void>>();
    final more = cubit.loadMore();
    final deletion = cubit.deleteNotification(cubit.state.items.single);
    repository.pendingPage!.complete(
      _page([_notification(), _notification(id: 'other')]),
    );
    await more;
    expect(cubit.state.items.map((item) => item.id), ['other']);
    repository.pendingDeletion!.complete(const Result.success(null));
    await deletion;
  });

  test('pagination waits while a full refresh is in progress', () async {
    await cubit.refresh();
    repository.pendingPage =
        Completer<Result<pagination.Page<AppNotification>>>();
    final refresh = cubit.refresh();
    await cubit.loadMore();
    expect(repository.pages, [0, 0]);
    repository.pendingPage!.complete(_page([_notification()]));
    await refresh;
  });

  for (final payload in [
    {
      'module': 'ARTIST_VENUE',
      'requestByType': 'VENUE',
      'action': 'REQUEST_CREATED',
      'bandId': 'band',
      'requestId': 'c0000000-0000-4000-8000-000000000001',
    },
    {
      'module': 'ARTIST_VENUE',
      'requestByType': 'BAND',
      'action': 'REQUEST_ACCEPTED',
      'bandId': 'band',
    },
  ]) {
    testWidgets(
      'band connection notification ${payload['action']} resolves current band membership',
      (tester) async {
        await serviceLocator.reset();
        final sessions = AudienceTestSessions(
          audienceSession(user: 'owner-1', role: 'ROLE_MUSICIAN'),
        );
        serviceLocator
          ..registerSingleton<AuthSessionManager>(sessions)
          ..registerSingleton<NotificationCubit>(cubit);
        addTearDown(() async {
          sessions.dispose();
          await serviceLocator.reset();
        });
        final bands = InvitationBands()
          ..read = (id) async => Result.success(invitationBand(id: id));
        serviceLocator.registerSingleton<BandRepository>(bands);
        final applicationsApi = RecordingApiClient((request) {
          expect(request.method, RecordedHttpMethod.get);
          expect(
            request.path,
            '${ArtistVenueConnectionEndpoints.base}/band/band/page',
          );
          expect(request.query, {'incoming': true, 'page': 0, 'size': 20});
          expect(request.requestContext?.expectedSessionKey, 'owner-1');
          return {
            'content': [],
            'page': 0,
            'size': 20,
            'totalElements': 0,
            'totalPages': 0,
            'last': true,
          };
        });
        serviceLocator.registerSingleton<ArtistVenueConnectionRepository>(
          ArtistVenueConnectionRepositoryImpl(applicationsApi),
        );
        final original = _notification(
          id: 'b724cbf7-8fbc-4709-a856-024ba1e96ba8',
          type: payload['action'] == 'REQUEST_CREATED'
              ? 'ARTIST_VENUE_LINK_APPLICATION_REQUEST'
              : 'ARTIST_VENUE_LINK_APPLICATION_ACCEPT',
          payload: payload,
        );
        repository.items = [
          AppNotification(
            id: original.id,
            recipientId: 'owner-1',
            type: original.type,
            title: original.title,
            message: original.message,
            read: original.read,
            createdAt: original.createdAt,
            payload: original.payload,
          ),
        ];
        final api = RecordingApiClient((request) {
          expect(request.method, RecordedHttpMethod.get);
          expect(request.path, '/api/v1/user/notifications/${original.id}');
          return {
            'id': original.id,
            'recipientId': 'owner-1',
            'type': original.type,
            'title': original.title,
            'message': original.message,
            'read': false,
            'payload': payload,
          };
        });
        serviceLocator.registerSingleton<NotificationTargetRepository>(
          NotificationTargetRepository(api, sessions),
        );
        RouteSettings? opened;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          BlocProvider<NotificationCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: const NotificationScreen(),
              navigatorObservers: [notificationTargetRouteObserver],
              onGenerateRoute: (settings) {
                opened = settings;
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('destination')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notification'));
        await tester.pumpAndSettle();
        if (payload['action'] == 'REQUEST_CREATED') {
          expect(opened, isNull);
          final panel = tester.widget<BandManagementPanelScreen>(
            find.byType(BandManagementPanelScreen),
          );
          expect(panel.profile.id, 'band');
          expect(panel.profile.members.single.isFounder, isTrue);
          expect(panel.profile.members.single.status, 'ACTIVE');
          expect(panel.openIncomingVenueApplications, isTrue);
          expect(find.text('Gelen İstekler'), findsOneWidget);
          expect(find.text('Gelen mekan isteği bulunmuyor.'), findsOneWidget);
          expect(applicationsApi.requests, hasLength(1));
          expect(bands.ids, ['band', 'band']);
        } else {
          expect(opened?.name, AppRoutes.bandPublicProfile);
          final envelope = opened?.arguments as NotificationReadArguments;
          expect(envelope.routeName, AppRoutes.bandPublicProfile);
          expect(envelope.ticket.notification.id, original.id);
          final args = envelope.arguments as BandProfileScreenArgs;
          expect(args.bandId, 'band');
          expect(args.viewMode, BandProfileViewMode.public);
          expect(applicationsApi.requests, isEmpty);
          expect(bands.ids, ['band']);
        }
        expect(api.requests, hasLength(1));
        expect(api.lastRequest.requestContext?.expectedSessionKey, 'owner-1');
        expect(
          api.lastRequest.requestContext?.expectedToken,
          sessions.session.token,
        );
        expect(cubit.state.items.single.id, original.id);
        expect(cubit.state.items.single.read, isFalse);
        expect(cubit.state.unreadCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

AppNotification _notification({
  String id = 'notification',
  String type = 'ARTIST_VENUE',
  Map<String, dynamic> payload = const {},
}) => AppNotification(
  id: id,
  recipientId: 'account',
  type: type,
  title: 'Notification',
  message: 'Message',
  read: false,
  createdAt: DateTime.utc(2026, 9),
  payload: payload,
);

Result<pagination.Page<AppNotification>> _page(List<AppNotification> items) =>
    Result.success(pagination.Page(items: items, hasNext: true));

class _Repository extends Fake implements NotificationRepository {
  int markAllCalls = 0;
  bool failMarkAll = false;
  @override
  Future<Result<int>> markAllAsRead() async {
    markAllCalls++;
    if (failMarkAll) {
      return const Result.failure(
        AppError(code: 'read_failed', message: 'Read failed'),
      );
    }
    final count = items.where((item) => !item.read).length;
    items = items.map((item) => item.copyWith(read: true)).toList();
    return Result.success(count);
  }

  List<AppNotification> items = [_notification()];
  final pages = <int>[];
  Completer<Result<pagination.Page<AppNotification>>>? pendingPage;
  Completer<Result<void>>? pendingDeletion;
  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    return pendingPage?.future ?? _page(items);
  }

  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((item) => !item.read).length);
  @override
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      const Result.success(null);
  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => pendingDeletion?.future ?? const Result.success(null);
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}
