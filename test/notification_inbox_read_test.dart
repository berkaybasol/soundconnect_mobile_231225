import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/media_notification_open_screen.dart';
import 'dart:async';
import 'support/media_image_http.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_conversation_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/media_detail_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _user = '70000000-0000-4000-8000-000000000001';
const _notice = '50000000-0000-4000-8000-000000000001';
const _conversation = '60000000-0000-4000-8000-000000000001';
const _media = {
  'uuid': '30000000-0000-4000-8000-000000000001',
  'kind': 'IMAGE',
  'title': 'Current authorized media',
  'sourceUrl': 'https://example.test/current.png',
};

void main() {
  late AudienceTestSessions sessions;
  late _Repository repository;
  late _Realtime realtime;
  late NotificationCubit cubit;
  late GlobalKey<NavigatorState> navigator;
  late RecordingApiClient api;
  late FutureOr<Object?> Function() mediaResponse;
  var reconciliations = 0;
  late MediaImageHttp imageHttp;
  Completer<void>? pendingAck;
  Map<String, dynamic>? overrideExact;

  setUp(() async {
    await serviceLocator.reset();
    imageHttp = MediaImageHttp()..install();
    sessions = AudienceTestSessions(audienceSession(user: _user));
    repository = _Repository();
    realtime = _Realtime();
    navigator = GlobalKey<NavigatorState>();
    mediaResponse = () => _media;
    pendingAck = null;
    overrideExact = null;
    api = RecordingApiClient((request) async {
      if (request.path.endsWith('/media')) return mediaResponse();
      if (request.path.endsWith('/read')) {
        await pendingAck?.future;
        final result = await repository.markAsRead(
          notificationId: request.path.split('/').reversed.elementAt(1),
        );
        if (!result.isSuccess) throw ApiException(result.error!);
        return null;
      }
      final row = repository.items.first;
      if (overrideExact != null) return overrideExact;
      return {
        'id': row.id,
        'recipientId': row.recipientId,
        'type': row.type,
        'read': row.read,
        'payload': row.payload,
      };
    });
    reconciliations = 0;
    cubit = NotificationCubit(
      repository,
      _Tokens(),
      sessions: sessions,
      realtimeClient: realtime,
      onDeliveryStateChanged: () async {
        reconciliations++;
      },
    );
    serviceLocator.registerSingleton<NotificationCubit>(cubit);
    serviceLocator.registerSingleton<NotificationTargetRepository>(
      NotificationTargetRepository(api, sessions),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<NotificationMediaRepository>(
      NotificationMediaRepository(api, sessions),
    );
    serviceLocator.registerSingleton<AudioHandler>(BaseAudioHandler());
    serviceLocator.registerSingleton<EngagementRepository>(_Engagement());
    serviceLocator.registerFactory<InteractionStatsCubit>(
      () => InteractionStatsCubit(_Engagement(), sessions: sessions),
    );
    serviceLocator.registerFactory<CommentThreadCubit>(
      () => CommentThreadCubit(_Engagement(), sessions: sessions),
    );
  });

  tearDown(() async {
    imageHttp.dispose();
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
    await serviceLocator.reset();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await cubit.ensureStarted();
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: cubit,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [notificationTargetRouteObserver],
          home: const NotificationScreen(),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                Scaffold(body: Text('Destination ${settings.name}')),
          ),
        ),
      ),
    );
    await paintMedia(tester);
  }

  void unread({int attempts = 0}) {
    expect(repository.readIds.length, attempts);
    expect(repository.items.every((row) => !row.read), isTrue);
    expect(cubit.state.items.every((row) => !row.read), isTrue);
    expect(cubit.state.unreadCount, 2);
    expect(reconciliations, 0);
  }

  testWidgets(
    'inbox entry and pending media lookup preserve target and sibling',
    (tester) async {
      final pending = Completer<Object?>();
      mediaResponse = () => pending.future;
      await mount(tester);
      unread();
      await tester.tap(find.text('Target notification'));
      await tester.pump();
      expect(api.requests, hasLength(2));
      unread();
      pending.complete(_media);
      await paintMedia(tester);
      expect(find.byType(MediaDetailScreen), findsOneWidget);
      expect(repository.readIds, [_notice]);
      expect(cubit.state.items.first.read, isTrue);
      expect(cubit.state.items.last.read, isFalse);
      expect(cubit.state.unreadCount, 1);
      expect(reconciliations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('unusable media image must not acknowledge the notification', (
    tester,
  ) async {
    mediaResponse = () => {
      'uuid': '30000000-0000-4000-8000-000000000001',
      'kind': 'IMAGE',
      'title': 'Broken media',
      'sourceUrl': null,
    };
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    unread();
  });

  for (final type in PushTarget.mediaTypes) {
    testWidgets('$type native open waits for decoded image then exact ACK', (
      tester,
    ) async {
      repository.items[0] = _row(type);
      final bytes = Completer<List<int>>();
      imageHttp.response = (_) => bytes.future;
      await mount(tester);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => MediaNotificationOpenScreen(
              target: PushTarget(
                notificationId: _notice,
                recipientId: _user,
                type: type,
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(MediaDetailScreen), findsOneWidget);
      unread();
      bytes.complete(MediaImageHttp.pixel);
      await paintMedia(tester);
      expect(repository.readIds, [_notice]);
      expect(cubit.state.unreadCount, 1);
      expect(repository.items.last.read, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'image transport failure needs explicit content retry before ACK',
    (tester) async {
      imageHttp.response = (_) async => throw StateError('503 image');
      await mount(tester);
      await tester.tap(find.text('Target notification'));
      await paintMedia(tester);
      expect(find.text('İçeriği tekrar yükle'), findsOneWidget);
      unread();
      final count = imageHttp.urls.length;
      await backgroundAndResume(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(imageHttp.urls, hasLength(count));
      unread();
      imageHttp.response = (_) async => MediaImageHttp.pixel;
      await tester.tap(find.text('İçeriği tekrar yükle'));
      await paintMedia(tester);
      expect(repository.readIds, [_notice]);
      expect(cubit.state.unreadCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final change in ['session', 'covered']) {
    testWidgets(
      'decoded media after $change cannot acknowledge a hidden or old account',
      (tester) async {
        final bytes = Completer<List<int>>();
        imageHttp.response = (_) => bytes.future;
        await mount(tester);
        await tester.tap(find.text('Target notification'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(find.byType(MediaDetailScreen), findsOneWidget);
        unread();
        if (change == 'session') {
          sessions.replace(
            audienceSession(user: '70000000-0000-4000-8000-000000000009'),
          );
        } else {
          unawaited(
            navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Covered')),
              ),
            ),
          );
        }
        bytes.complete(MediaImageHttp.pixel);
        await paintMedia(tester);
        expect(repository.readIds, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'second media tap while first detail remains opens its own target and exact read',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Target notification'));
      await paintMedia(tester);
      const secondId = '50000000-0000-4000-8000-000000000002';
      const secondMedia = '30000000-0000-4000-8000-000000000002';
      final second = AppNotification(
        id: secondId,
        recipientId: _user,
        type: 'SOCIAL_LIKE',
        title: 'Second',
        message: '',
        read: false,
        createdAt: null,
        payload: {..._row('SOCIAL_LIKE').payload, 'targetId': secondMedia},
      );
      repository.items.add(second);
      overrideExact = {
        'id': second.id,
        'recipientId': second.recipientId,
        'type': second.type,
        'read': false,
        'payload': second.payload,
      };
      mediaResponse = () => {
        ..._media,
        'uuid': secondMedia,
        'title': 'Second current media',
        'sourceUrl': 'https://example.test/second.png',
      };
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const MediaNotificationOpenScreen(
              target: PushTarget(
                notificationId: secondId,
                recipientId: _user,
                type: 'SOCIAL_LIKE',
              ),
            ),
          ),
        ),
      );
      await paintMedia(tester);
      expect(find.text('Second current media'), findsWidgets);
      expect(
        tester
            .widget<MediaDetailScreen>(find.byType(MediaDetailScreen))
            .targetId,
        secondMedia,
      );
      expect(repository.readIds, [_notice, secondId]);
      expect(repository.items[1].read, isFalse);
      expect(repository.allReads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'media GET 503 never auto retries and explicit retry opens content',
    (tester) async {
      mediaResponse = () => throw StateError('503 target');
      await mount(tester);
      await tester.tap(find.text('Target notification'));
      await paintMedia(tester);
      unread();
      expect(find.byType(MediaDetailScreen), findsNothing);
      final count = api.requests.length;
      await backgroundAndResume(tester);
      await paintMedia(tester);
      expect(api.requests, hasLength(count));
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(find.text('Tekrar dene').hitTestable(), findsOneWidget);
      unread();
      mediaResponse = () => _media;
      await tester.tap(find.text('Tekrar dene').hitTestable());
      await paintMedia(tester);
      expect(find.byType(MediaDetailScreen), findsOneWidget);
      expect(repository.readIds, [_notice]);
      expect(cubit.state.unreadCount, 1);
      navigator.currentState!.pop();
      await paintMedia(tester);
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('ACK retry is single flight with no GET or second route', (
    tester,
  ) async {
    repository.failRead = true;
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    unread(attempts: 1);
    final getCount = api.requests
        .where((r) => !r.path.endsWith('/read'))
        .length;
    final firstDetail = tester.widget<MediaDetailScreen>(
      find.byType(MediaDetailScreen),
    );
    await backgroundAndResume(tester);
    await paintMedia(tester);
    unread(attempts: 1);
    pendingAck = Completer<void>();
    repository.failRead = false;
    final retry = tester
        .widget<SnackBarAction>(find.byType(SnackBarAction))
        .onPressed;
    retry();
    retry();
    await tester.pump();
    expect(api.requests.where((r) => r.path.endsWith('/read')), hasLength(2));
    pendingAck!.complete();
    await paintMedia(tester);
    expect(repository.readIds, [_notice, _notice]);
    expect(cubit.state.unreadCount, 1);
    expect(
      api.requests.where((r) => !r.path.endsWith('/read')),
      hasLength(getCount),
    );
    expect(
      tester.widget<MediaDetailScreen>(find.byType(MediaDetailScreen)),
      same(firstDetail),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final field in [
    'id',
    'recipientId',
    'type',
    'module',
    'targetType',
    'targetId',
    'actorId',
    'mediaIdentityVersion',
    'commentId',
  ]) {
    testWidgets(
      'fresh exact notification rejects wrong $field without resolver or ACK',
      (tester) async {
        final row = repository.items.first;
        overrideExact = {
          'id': row.id,
          'recipientId': row.recipientId,
          'type': row.type,
          'read': false,
          'payload': {...row.payload},
        };
        if (['id', 'recipientId', 'type'].contains(field)) {
          overrideExact![field] = 'wrong';
        } else {
          (overrideExact!['payload'] as Map)[field] = 'wrong';
        }
        await mount(tester);
        await tester.tap(find.text('Target notification'));
        await paintMedia(tester);
        expect(find.byType(MediaDetailScreen), findsNothing);
        unread();
        expect(api.requests, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final failure in ['throw', 'wrong-target', 'invalid-kind']) {
    testWidgets(
      'media $failure keeps both rows unread and OS reconciliation untouched',
      (tester) async {
        mediaResponse = () => switch (failure) {
          'throw' => throw StateError('Transport unavailable'),
          'wrong-target' => {..._media, 'uuid': 'different'},
          _ => {..._media, 'kind': 'UNKNOWN'},
        };
        await mount(tester);
        await tester.tap(find.text('Target notification'));
        await paintMedia(tester);
        expect(find.byType(MediaDetailScreen), findsNothing);
        unread();
      },
    );
  }

  testWidgets('read failure keeps actual media usable and both rows unread', (
    tester,
  ) async {
    repository.failRead = true;
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    expect(find.text('Current authorized media'), findsWidgets);
    unread(attempts: 1);
    await tester.pump(const Duration(seconds: 2));
    unread(attempts: 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a deliberate re-open retries only the failed target ACK', (
    tester,
  ) async {
    repository.failRead = true;
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    unread(attempts: 1);
    navigator.currentState!.pop();
    await paintMedia(tester);
    repository.failRead = false;
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    expect(repository.readIds, [_notice, _notice]);
    expect(cubit.state.items.first.read, isTrue);
    expect(cubit.state.items.last.read, isFalse);
    expect(cubit.state.unreadCount, 1);
    expect(reconciliations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final outcome in ['missing', 'cancelled', 'restricted']) {
    testWidgets('social $outcome target preserves both unread rows', (
      tester,
    ) async {
      repository.items[0] = _row(
        'SOCIAL_FOLLOW',
        payload: {'module': 'SOCIAL', 'followerId': 'follower'},
      );
      serviceLocator.registerSingleton<DmUserProfileResolver>(
        _Profiles(switch (outcome) {
          'missing' => [],
          'restricted' => [const DmProfileTarget.studioRestricted()],
          _ => [
            const DmProfileTarget(
              type: DmProfileTargetType.musician,
              id: 'musician',
              displayName: 'Musician choice',
              imageUrl: null,
            ),
            const DmProfileTarget(
              type: DmProfileTargetType.listener,
              id: 'listener',
              displayName: 'Listener choice',
              imageUrl: null,
            ),
          ],
        }),
      );
      await mount(tester);
      await tester.tap(find.text('Target notification'));
      await paintMedia(tester);
      if (outcome == 'cancelled') {
        expect(find.text('Musician choice'), findsOneWidget);
        navigator.currentState!.pop();
        await paintMedia(tester);
      } else if (outcome == 'restricted') {
        expect(
          find.text('Destination ${AppRoutes.studioListenerInfo}'),
          findsOneWidget,
        );
      }
      unread();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final interruption in ['covered', 'background', 'token']) {
    testWidgets(
      'pending inbox media $interruption cannot open or consume target',
      (tester) async {
        final pending = Completer<Object?>();
        mediaResponse = () => pending.future;
        await mount(tester);
        await tester.tap(find.text('Target notification'));
        await tester.pump();
        if (interruption == 'covered') {
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
        } else if (interruption == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          await tester.runAsync(() async {
            sessions.replace(audienceSession(user: _user, token: 'rotated'));
            await cubit.stop();
          });
        }
        pending.complete(_media);
        await paintMedia(tester);
        expect(find.byType(MediaDetailScreen), findsNothing);
        expect(repository.readIds, isEmpty);
        expect(repository.items.every((row) => !row.read), isTrue);
        expect(reconciliations, 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('unsupported row leaves read state unchanged', (tester) async {
    repository.items[0] = _row('UNKNOWN_NOTIFICATION');
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    unread();
  });

  testWidgets('explicit mark-all remains an intentional operation', (
    tester,
  ) async {
    await mount(tester);
    unread();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await paintMedia(tester);
    await tester.tap(find.text('Tümünü oku'));
    await paintMedia(tester);
    expect(repository.allReads, 1);
    expect(repository.items.every((row) => row.read), isTrue);
    expect(cubit.state.unreadCount, 0);
  });

  testWidgets('inbox DM failure uses guarded opener without notification ACK', (
    tester,
  ) async {
    repository.items[0] = _row(
      'DM_NEW_MESSAGE',
      payload: {'conversationId': _conversation},
    );
    final dm = _Dm();
    serviceLocator.registerSingleton<DmRepository>(dm);
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    expect(find.byType(DmNotificationOpenScreen), findsNothing);
    expect(
      find.byType(DmNotificationOpenScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(NotificationScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(dm.previewIds, [_conversation]);
    unread();
  });

  testWidgets(
    'successful inbox DM resolution delegates read to actual chat lifecycle',
    (tester) async {
      repository.items[0] = _row(
        'DM_NEW_MESSAGE',
        payload: {'conversationId': _conversation},
      );
      final dm = _Dm()..success = true;
      serviceLocator.registerSingleton<DmRepository>(dm);
      await mount(tester);
      await tester.tap(find.text('Target notification'));
      await paintMedia(tester);
      expect(find.text('Destination ${AppRoutes.dmChat}'), findsOneWidget);
      // This stub destination intentionally does not emulate the real chat ACK.
      unread();
    },
  );
}

AppNotification _row(String type, {Map<String, dynamic>? payload}) =>
    AppNotification(
      id: _notice,
      recipientId: _user,
      type: type,
      title: 'Target notification',
      message: '',
      read: false,
      createdAt: null,
      payload:
          payload ??
          const {
            'module': 'SOCIAL',
            'mediaIdentityVersion': 1,
            'actorId': '20000000-0000-4000-8000-000000000001',
            'commentId': '40000000-0000-4000-8000-000000000001',
            'targetType': 'MEDIA',
            'targetId': '30000000-0000-4000-8000-000000000001',
          },
    );

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [
    _row('SOCIAL_COMMENT'),
    AppNotification(
      id: 'sibling',
      recipientId: _user,
      type: 'SOCIAL_LIKE',
      title: 'Sibling notification',
      message: '',
      read: false,
      createdAt: null,
      payload: const {},
    ),
  ];
  final readIds = <String>[];
  bool failRead = false;
  int allReads = 0;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: items, hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((row) => !row.read).length);
  @override
  Future<Result<void>> markAsRead({required String notificationId}) async {
    readIds.add(notificationId);
    if (failRead) {
      return const Result.failure(
        AppError(code: 'offline', message: 'Read unavailable'),
      );
    }
    items = [
      for (final row in items)
        if (row.id == notificationId) row.copyWith(read: true) else row,
    ];
    return const Result.success(null);
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    allReads++;
    final count = items.where((row) => !row.read).length;
    items = [for (final row in items) row.copyWith(read: true)];
    return Result.success(count);
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Profiles implements DmUserProfileResolver {
  _Profiles(this.targets);
  final List<DmProfileTarget> targets;

  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async => targets;
}

class _Realtime extends NotificationRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class _Engagement extends Fake implements EngagementRepository {
  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async => const Result.success(1);
  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async => const Result.success(false);
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _Dm extends Fake implements DmRepository {
  bool success = false;
  final previewIds = <String>[];
  @override
  Future<Result<DmConversationPreview>> getConversationPreview({
    required String conversationId,
  }) async {
    previewIds.add(conversationId);
    if (!success) {
      return const Result.failure(
        AppError(code: 'offline', message: 'Unavailable'),
      );
    }
    return Result.success(
      DmConversationPreview(
        conversationId: conversationId,
        otherUserId: '70000000-0000-4000-8000-000000000002',
        otherUsername: 'Current sender',
        otherUserProfilePicture: null,
        lastMessageContent: '',
        lastMessageType: 'text',
        lastMessageSenderId: 'sender',
        lastMessageAt: DateTime.utc(2026),
        lastMessageRead: false,
      ),
    );
  }
}
