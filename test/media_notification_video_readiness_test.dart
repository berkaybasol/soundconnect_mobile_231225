import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
// Exercise video_player's pinned platform contract without a second version pin.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
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
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
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
  late _VideoPlatform platform;
  late VideoPlayerPlatform previousPlatform;
  var reconciliations = 0;
  late MediaImageHttp imageHttp;
  Completer<void>? pendingAck;
  Map<String, dynamic>? overrideExact;

  setUp(() async {
    await serviceLocator.reset();
    previousPlatform = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
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
    VideoPlayerPlatform.instance = previousPlatform;
    for (final stream in platform.events.values) {
      await stream.close();
    }
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

  Future<void> openVideo(
    WidgetTester tester, {
    String type = 'SOCIAL_COMMENT',
  }) async {
    repository.items[0] = _row(type);
    mediaResponse = () => {
      ..._media,
      'kind': 'VIDEO',
      'playbackUrl': 'https://example.test/current.mp4',
    };
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    for (
      var frame = 0;
      frame < 12 &&
          (platform.events.isEmpty ||
              find.byType(MediaDetailScreen).evaluate().isEmpty);
      frame++
    ) {
      await tester.pump();
    }
    expect(find.byType(MediaDetailScreen), findsOneWidget);
    expect(platform.events, hasLength(1));
  }

  Future<VideoPlayerController> initialize(WidgetTester tester, int id) async {
    platform.initialize(id);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 30));
    return tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('malformed exact response displays the shared Turkish error', (
    tester,
  ) async {
    overrideExact = {'id': 'wrong'};
    await mount(tester);
    await tester.tap(find.text('Target notification'));
    await paintMedia(tester);
    expect(
      find.text(
        'Bildirim şu anda açılamıyor. Bağlantını kontrol edip tekrar dene.',
      ),
      findsOneWidget,
    );
    unread();
    await finish(tester);
  });

  test(
    'captured session rejected by real repository returns readable Turkish',
    () async {
      final captured = sessions.session;
      sessions.replace(audienceSession(user: _user, token: 'new'));
      final result = await serviceLocator<NotificationTargetRepository>()
          .resolveMedia(
            const PushTarget(
              notificationId: _notice,
              recipientId: _user,
              type: 'SOCIAL_COMMENT',
            ),
            captured,
          );
      expect(result.isSuccess, isFalse);
      expect(result.error!.code, 'notification_target_session_changed');
      expect(result.error!.message, 'Oturum değişti. Bildirimi yeniden aç.');
      expect(api.requests, isEmpty);
    },
  );

  for (final type in PushTarget.mediaTypes) {
    for (final fail in [false, true]) {
      testWidgets(
        '$type initialized then ${fail ? "platform error before ACK stays unread" : "visible video acknowledges exactly once"}',
        (tester) async {
          await openVideo(tester, type: type);
          final controller = await initialize(tester, 1);
          unread();
          if (fail) {
            platform.fail(1);
            await tester.pump();
            expect(controller.value.hasError, isTrue);
            expect(controller.value.isInitialized, isFalse);
            unread();
          }
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          if (fail) {
            unread();
            expect(
              find.text('Video açılamadı. Lütfen tekrar dene.'),
              findsOneWidget,
            );
          } else {
            expect(repository.readIds, [_notice]);
            expect(repository.items.last.read, isFalse);
            expect(cubit.state.unreadCount, 1);
            // A later playback failure never undoes a confirmed read or repeats it.
            platform.fail(1);
            await paintMedia(tester);
            await backgroundAndResume(tester);
            expect(repository.readIds, [_notice]);
            expect(cubit.state.items.first.read, isTrue);
          }
          await finish(tester);
        },
      );
    }
  }

  testWidgets(
    'player error requires explicit reload; retired controller cannot ready retry',
    (tester) async {
      await openVideo(tester);
      await initialize(tester, 1);
      platform.fail(1);
      await paintMedia(tester);
      unread();
      await backgroundAndResume(tester);
      expect(platform.events, hasLength(1));
      unread();
      await tester.tap(find.text('Video açılamadı. Lütfen tekrar dene.'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      expect(platform.events, hasLength(2));
      expect(platform.disposed, contains(1));
      platform.initialize(1); // Late events from the disposed attempt.
      await paintMedia(tester);
      unread();
      expect(find.byType(VideoPlayer), findsNothing);
      await initialize(tester, 2);
      await paintMedia(tester);
      expect(repository.readIds, [_notice]);
      expect(cubit.state.unreadCount, 1);
      expect(repository.items.last.read, isFalse);
      await finish(tester);
    },
  );

  testWidgets(
    'unavailable player removes ACK recovery; only usable content permits explicit ACK',
    (tester) async {
      repository.failRead = true;
      await openVideo(tester);
      await initialize(tester, 1);
      await paintMedia(tester);
      unread(attempts: 1);
      final requests = api.requests.length;
      expect(find.text('Tekrar dene'), findsOneWidget);
      platform.fail(1);
      await paintMedia(tester);
      expect(find.text('Tekrar dene'), findsNothing);
      await backgroundAndResume(tester);
      unread(attempts: 1);
      expect(api.requests, hasLength(requests));
      repository.failRead = false;
      await tester.tap(find.text('Video açılamadı. Lütfen tekrar dene.'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      await initialize(tester, 2);
      await paintMedia(tester);
      unread(attempts: 1);
      pendingAck = Completer<void>();
      final retry = tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
      retry();
      retry();
      await tester.pump();
      expect(api.requests.length, requests + 1);
      pendingAck!.complete();
      await paintMedia(tester);
      expect(repository.readIds, [_notice, _notice]);
      expect(repository.items.last.read, isFalse);
      expect(cubit.state.unreadCount, 1);
      await finish(tester);
    },
  );

  for (final interruption in ['covered', 'background', 'session', 'disposed']) {
    testWidgets(
      'pending player completion after $interruption cannot acknowledge hidden target',
      (tester) async {
        await openVideo(tester);
        if (interruption == 'covered') {
          unawaited(
            navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
        } else if (interruption == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else if (interruption == 'session') {
          sessions.replace(audienceSession(user: _user, token: 'changed'));
        } else {
          navigator.currentState!.pop();
        }
        platform.initialize(1);
        await paintMedia(tester);
        expect(repository.readIds, isEmpty);
        expect(repository.items.every((row) => !row.read), isTrue);
        if (interruption == 'covered' || interruption == 'background') {
          platform.fail(1);
          await tester.pump();
          if (interruption == 'covered') navigator.currentState!.pop();
          if (interruption == 'background') {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
          }
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await paintMedia(tester);
          unread();
        }
        await finish(tester);
      },
    );
  }

  testWidgets(
    'second video target ignores old player error and reads only current exact notification',
    (tester) async {
      await openVideo(tester);
      const secondId = '50000000-0000-4000-8000-000000000002';
      const secondMedia = '30000000-0000-4000-8000-000000000002';
      final second = AppNotification(
        id: secondId,
        recipientId: _user,
        type: 'SOCIAL_LIKE',
        title: 'Second notification',
        message: '',
        read: false,
        createdAt: null,
        payload: {..._row('SOCIAL_LIKE').payload, 'targetId': secondMedia},
      );
      repository.items.add(second);
      overrideExact = {
        'id': secondId,
        'recipientId': _user,
        'type': second.type,
        'read': false,
        'payload': second.payload,
      };
      mediaResponse = () => {
        ..._media,
        'uuid': secondMedia,
        'kind': 'VIDEO',
        'title': 'Second video',
        'playbackUrl': 'https://example.test/second.mp4',
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
      for (var i = 0; i < 15 && platform.events.length < 2; i++) {
        await tester.pump();
      }
      expect(platform.events, hasLength(2));
      platform.initialize(1);
      platform.fail(1);
      await paintMedia(tester);
      expect(repository.readIds, isEmpty);
      expect(find.text('Video yükleniyor...'), findsOneWidget);
      await initialize(tester, 2);
      await paintMedia(tester);
      expect(repository.readIds, [secondId]);
      expect(repository.items.first.read, isFalse);
      expect(repository.items[1].read, isFalse);
      expect(
        tester
            .widget<MediaDetailScreen>(find.byType(MediaDetailScreen))
            .targetId,
        secondMedia,
      );
      await finish(tester);
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

class _VideoPlatform extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  void initialize(int id) => events[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(640, 360),
    ),
  );
  void fail(int id) => events[id]!.addError(
    PlatformException(code: 'VideoError', message: 'Task decoder failure'),
  );
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    final id = events.length + 1;
    events[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => events[id]!.stream;
  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> play(int id) async {}
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration position) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildView(int id) => const SizedBox.expand();
}
