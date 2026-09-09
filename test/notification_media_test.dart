import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/media_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _media = {
  'uuid': 'asset-1',
  'kind': 'AUDIO',
  'title': 'Fresh audio',
  'playbackUrl': 'https://example.test/current.mp3',
};

void main() {
  tearDown(() async => serviceLocator.reset());

  test(
    'notification target uses recipient session and current response',
    () async {
      final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
      final api = RecordingApiClient((_) => _media);
      final result = await NotificationMediaRepository(
        api,
        sessions,
      ).resolve('notice/1', 'asset-1');
      expect(result.data?.playbackUrl, 'https://example.test/current.mp3');
      expect(
        api.lastRequest.path,
        '/api/v1/user/notifications/notice%2F1/media',
      );
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'owner');
    },
  );

  test('guest never dispatches private notification lookup', () async {
    final api = RecordingApiClient((_) => _media);
    final result = await NotificationMediaRepository(
      api,
      AudienceTestSessions(const AuthSession.guest()),
    ).resolve('n', 'asset-1');
    expect(result.isSuccess, isFalse);
    expect(api.requests, isEmpty);
  });

  test('wrong target response is rejected', () async {
    final result = await NotificationMediaRepository(
      RecordingApiClient((_) => _media),
      AudienceTestSessions(audienceSession()),
    ).resolve('n', 'another-asset');
    expect(result.isSuccess, isFalse);
  });

  test('late response cannot cross account boundary', () async {
    final pending = Completer<Object?>();
    final sessions = AudienceTestSessions(audienceSession());
    final repository = NotificationMediaRepository(
      RecordingApiClient((_) => pending.future),
      sessions,
    );
    final result = repository.resolve('n', 'asset-1');
    sessions.replace(audienceSession(user: 'another'));
    pending.complete(_media);
    expect((await result).isSuccess, isFalse);
  });

  for (final type in ['SOCIAL_LIKE', 'SOCIAL_COMMENT']) {
    testWidgets(
      '$type opens actual media detail with comment and stats providers',
      (tester) async {
        final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
        serviceLocator.registerSingleton<AuthSessionManager>(sessions);
        serviceLocator.registerSingleton<NotificationMediaRepository>(
          NotificationMediaRepository(
            RecordingApiClient((_) => _media),
            sessions,
          ),
        );
        serviceLocator.registerSingleton<AudioHandler>(BaseAudioHandler());
        serviceLocator.registerSingleton<EngagementRepository>(_Engagement());
        serviceLocator.registerFactory<InteractionStatsCubit>(
          () => InteractionStatsCubit(_Engagement(), sessions: sessions),
        );
        serviceLocator.registerFactory<CommentThreadCubit>(
          () => CommentThreadCubit(_Engagement(), sessions: sessions),
        );
        final cubit = _Notifications(type);
        addTearDown(cubit.close);
        await tester.pumpWidget(
          BlocProvider<NotificationCubit>.value(
            value: cubit,
            child: const MaterialApp(home: NotificationScreen()),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Test notification'));
        await tester.pumpAndSettle();
        expect(find.byType(MediaDetailScreen), findsOneWidget);
        final detail = tester.widget<MediaDetailScreen>(
          find.byType(MediaDetailScreen),
        );
        expect(detail.targetId, 'asset-1');
        expect(detail.title, 'Fresh audio');
        expect(detail.playbackUrl, 'https://example.test/current.mp3');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final change in ['route', 'notification', 'session']) {
    testWidgets('pending media lookup cannot navigate after $change changes', (
      tester,
    ) async {
      final response = Completer<Object?>();
      final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
      final api = RecordingApiClient((_) => response.future);
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<NotificationMediaRepository>(
        NotificationMediaRepository(api, sessions),
      );
      serviceLocator.registerSingleton<AudioHandler>(BaseAudioHandler());
      serviceLocator.registerFactory<InteractionStatsCubit>(
        () => InteractionStatsCubit(_Engagement(), sessions: sessions),
      );
      serviceLocator.registerFactory<CommentThreadCubit>(
        () => CommentThreadCubit(_Engagement(), sessions: sessions),
      );
      final cubit = _Notifications('SOCIAL_LIKE');
      addTearDown(cubit.close);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const NotificationScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Test notification'));
      await tester.pump();
      await tester.tap(find.text('Test notification'));
      expect(api.requests, hasLength(1));
      switch (change) {
        case 'route':
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Another screen')),
              ),
            ),
          );
        case 'notification':
          cubit.replaceNotification();
        case 'session':
          sessions.replace(audienceSession(user: 'other'));
      }
      await tester.pumpAndSettle();
      response.complete(_media);
      await tester.pumpAndSettle();
      expect(find.byType(MediaDetailScreen), findsNothing);
      if (change == 'route') {
        expect(find.text('Another screen'), findsOneWidget);
      } else if (change == 'notification') {
        expect(find.text('Replacement notification'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _Notifications extends Cubit<NotificationState>
    implements NotificationCubit {
  _Notifications(String type)
    : super(
        const NotificationState.initial().copyWith(
          status: NotificationStatus.success,
          items: [
            AppNotification(
              id: 'notice',
              recipientId: 'owner',
              type: type,
              title: 'Test notification',
              message: '',
              read: true,
              createdAt: null,
              payload: const {
                'targetType': 'MEDIA',
                'targetId': 'asset-1',
                'playbackUrl': 'https://example.test/stale.mp3',
              },
            ),
          ],
        ),
      );
  @override
  Future<void> refresh() async {}
  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<void> markAsRead(AppNotification notification) async {}

  void replaceNotification() => emit(
    state.copyWith(
      items: [
        AppNotification(
          id: 'replacement-notice',
          recipientId: 'owner',
          type: 'SOCIAL_LIKE',
          title: 'Replacement notification',
          message: '',
          read: true,
          createdAt: null,
          payload: const {'targetType': 'MEDIA', 'targetId': 'asset-2'},
        ),
      ],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
