import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'support/recording_api_client.dart';
import 'dart:async';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';

import 'support/event_audience_fakes.dart';

final _post = OverthinkingPostModel.fromJson({
  'id': '30000000-0000-4000-8000-000000000001',
  'title': 'Current private post',
  'content': 'Only the intended recipient can open this response.',
  'authorId': 'author',
  'authorUsername': 'approved-author',
  'anonymous': true,
  'canViewAuthor': true,
  'visibilityType': 'ANONYMOUS',
});

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  Future<_Harness> failedDetail(WidgetTester tester) async {
    final h = _Harness(read: false);
    h.posts.detailPending = Completer<Result<OverthinkingPost>>();
    await h.mount(tester);
    await tester.tap(find.text('Approved notification'));
    await tester.pumpAndSettle();
    h.posts.detailPending!.complete(
      const Result.failure(
        AppError(code: '503', message: 'Controlled destination failure'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.posts.reads, hasLength(2));
    expect(h.acknowledgements, 0);
    return h;
  }

  testWidgets(
    'second GET503 keeps target retry for 20s then fresh consent precedes ACK-only retry',
    (tester) async {
      final h = await failedDetail(tester);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.posts.reads, hasLength(2));
      expect(h.acknowledgements, 0);
      h.posts.detailPending = Completer<Result<OverthinkingPost>>();
      h.ackFailures = 1;
      final retry = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      retry.onPressed();
      retry.onPressed();
      await tester.pumpAndSettle();
      expect(
        h.posts.reads,
        hasLength(3),
        reason: 'double action shares one detail flight',
      );
      expect(h.acknowledgements, 0);
      h.posts.detailPending!.complete(
        Result.success(_post.copyWith(title: 'Fresh after explicit retry')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh after explicit retry'), findsOneWidget);
      expect(h.acknowledgements, 1);
      expect(h.notices.confirmations, 0);
      expect(find.text('İçerik güncellenemedi.'), findsNothing);
      expect(find.text('Okundu bilgisi kaydedilemedi.'), findsOneWidget);
      final lookups = h.lookups,
          posts = h.posts.reads.length,
          comments = h.engagement.targets.length;
      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(h.acknowledgements, 2);
      expect(h.notices.confirmations, 1);
      expect(h.lookups, lookups);
      expect(h.posts.reads, hasLength(posts));
      expect(h.engagement.targets, hasLength(comments));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final change in ['hidden', 'cover', 'session', 'dispose']) {
    testWidgets(
      'explicit detail retry rejects late reply after $change without auto retry or ACK',
      (tester) async {
        final h = await failedDetail(tester);
        h.posts.detailPending = Completer<Result<OverthinkingPost>>();
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(h.posts.reads, hasLength(3));
        if (change == 'hidden') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else if (change == 'cover') {
          unawaited(
            h.navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          h.navigator.currentState!.pop();
        } else if (change == 'session') {
          h.sessions.replace(
            audienceSession(user: 'new-account', token: 'new'),
          );
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        h.posts.detailPending!.complete(
          Result.success(_post.copyWith(title: 'Stale hidden reply')),
        );
        await tester.pumpAndSettle();
        expect(h.acknowledgements, 0);
        expect(h.notices.confirmations, 0);
        expect(find.text('Stale hidden reply'), findsNothing);
        await tester.pump(const Duration(seconds: 20));
        expect(h.posts.reads, hasLength(3));
        if (change == 'hidden' || change == 'cover') {
          expect(find.text('Tekrar dene'), findsOneWidget);
          h.posts.detailPending = null;
          await tester.tap(find.text('Tekrar dene'));
          await tester.pumpAndSettle();
          expect(h.posts.reads, hasLength(4));
          expect(h.acknowledgements, 1);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final invalid in ['consent', 'post']) {
    testWidgets(
      'explicit target retry $invalid mismatch never acknowledges cached approved author',
      (tester) async {
        final h = await failedDetail(tester);
        h.posts.detailPending = null;
        h.posts.result = invalid == 'consent'
            ? _post.copyWith(canViewAuthor: false, authorId: null)
            : _post.copyWith(id: '30000000-0000-4000-8000-000000000009');
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(h.posts.reads, hasLength(3));
        expect(h.acknowledgements, 0);
        expect(h.notices.confirmations, 0);
        if (invalid == 'consent') {
          expect(find.text('@approved-author'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'failed destination Home and route return only restore explicit target retry',
    (tester) async {
      final h = await failedDetail(tester);
      // Android first becomes inactive, then paused (where frames are disabled).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(h.posts.reads, hasLength(2));
      expect(h.acknowledgements, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      unawaited(
        h.navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsNothing);
      h.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.posts.reads, hasLength(2));
      expect(h.acknowledgements, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'approved unread waits for destination fresh detail before ACK and confirms once',
    (tester) async {
      final h = _Harness(read: false);
      h.posts.detailPending = Completer<Result<OverthinkingPost>>();
      h.ackPending = Completer<Object?>();
      await h.mount(tester);
      await tester.tap(find.text('Approved notification'));
      await tester.pumpAndSettle();
      expect(find.text(_post.title), findsOneWidget);
      expect(h.acknowledgements, 0);
      h.posts.detailPending!.complete(
        Result.success(_post.copyWith(title: 'Fresh destination post')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh destination post'), findsOneWidget);
      expect(h.acknowledgements, 1);
      h.ackPending!.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsNothing);
      expect(h.notices.confirmations, 1);
      await tester.pump(const Duration(seconds: 20));
      expect(h.acknowledgements, 1);
      expect(find.text('Okundu bilgisi kaydedilemedi.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final invalid in ['consent', 'post']) {
    testWidgets(
      'approved destination refresh $invalid change cannot ACK opener snapshot',
      (tester) async {
        final h = _Harness(read: false);
        h.posts.detailPending = Completer<Result<OverthinkingPost>>();
        await h.mount(tester);
        await tester.tap(find.text('Approved notification'));
        await tester.pumpAndSettle();
        expect(h.acknowledgements, 0);
        h.posts.detailPending!.complete(
          Result.success(
            invalid == 'consent'
                ? _post.copyWith(canViewAuthor: false, authorId: null)
                : _post.copyWith(id: '30000000-0000-4000-8000-000000000009'),
          ),
        );
        await tester.pumpAndSettle();
        expect(h.acknowledgements, 0);
        expect(h.notices.confirmations, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final invalid in ['consent', 'post']) {
    testWidgets(
      'approved fresh $invalid mismatch never opens cached author detail',
      (tester) async {
        final h = _Harness();
        h.posts.result = invalid == 'consent'
            ? _post.copyWith(canViewAuthor: false, authorId: null)
            : _post.copyWith(id: '30000000-0000-4000-8000-000000000009');
        await h.mount(tester);
        await tester.tap(find.text('Approved notification'));
        await tester.pumpAndSettle();
        expect(h.createdDetailCubits, 0);
        expect(find.byType(OverthinkingDetailScreen), findsNothing);
        expect(find.text('@approved-author'), findsNothing);
      },
    );
  }

  testWidgets(
    'wrong recipient cannot dispatch Overthinking notification lookup',
    (tester) async {
      final h = _Harness(recipient: 'someone-else');
      await h.mount(tester);
      await tester.tap(find.text('Approved notification'));
      await tester.pumpAndSettle();

      expect(h.posts.reads, isEmpty);
      expect(h.createdDetailCubits, 0);
      expect(find.byType(OverthinkingDetailScreen), findsNothing);
      expect(find.text(_post.title), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final change in ['account', 'route']) {
    testWidgets(
      'pending Overthinking lookup cannot navigate after $change changes',
      (tester) async {
        final h = _Harness();
        h.posts.pending = Completer<Result<OverthinkingPost>>();
        await h.mount(tester);
        await tester.tap(find.text('Approved notification'));
        await tester.pump();
        expect(h.posts.reads, ['30000000-0000-4000-8000-000000000001']);

        if (change == 'account') {
          h.sessions.replace(
            audienceSession(user: 'new-account', token: 'new'),
          );
        } else {
          unawaited(
            h.navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    const Scaffold(body: Text('Covered notification route')),
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        h.posts.pending!.complete(Result.success(_post));
        await tester.pumpAndSettle();

        expect(h.createdDetailCubits, 0);
        expect(find.byType(OverthinkingDetailScreen), findsNothing);
        expect(find.text(_post.title), findsNothing);
        expect(find.text('@approved-author'), findsNothing);
        if (change == 'route') {
          expect(find.text('Covered notification route'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'current recipient opens fresh Overthinking detail with providers',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await tester.tap(find.text('Approved notification'));
      await tester.pumpAndSettle();

      expect(h.createdDetailCubits, 1);
      expect(h.posts.reads, [
        '30000000-0000-4000-8000-000000000001',
        '30000000-0000-4000-8000-000000000001',
      ]);
      expect(find.byType(OverthinkingDetailScreen), findsOneWidget);
      expect(find.text(_post.title), findsOneWidget);
      expect(find.text('@approved-author'), findsOneWidget);
      expect(h.engagement.targets, ['30000000-0000-4000-8000-000000000001']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Harness {
  _Harness({
    String recipient = '70000000-0000-4000-8000-000000000001',
    bool read = true,
  }) : notices = _Notices(recipient, read: read) {
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<OverthinkingRepository>(posts)
      ..registerSingleton<EngagementRepository>(engagement)
      ..registerFactory<OverthinkingFeedCubit>(() {
        createdDetailCubits++;
        return OverthinkingFeedCubit(
          overthinkingRepository: posts,
          engagementRepository: engagement,
          sessions: sessions,
        );
      })
      ..registerFactory<CommentThreadCubit>(
        () => CommentThreadCubit(engagement, sessions: sessions),
      );
    serviceLocator.registerSingleton<NotificationCubit>(notices);
    serviceLocator.registerSingleton<NotificationTargetRepository>(
      NotificationTargetRepository(
        RecordingApiClient((request) {
          if (request.path.endsWith('/read')) {
            acknowledgements++;
            if (ackFailures > 0) {
              ackFailures--;
              throw StateError('Controlled ACK503');
            }
            return ackPending?.future;
          }
          lookups++;
          return {
            'id': notices.state.items.single.id,
            'recipientId': notices.state.items.single.recipientId,
            'type': notices.state.items.single.type,
            'read': notices.state.items.single.read,
            'payload': notices.state.items.single.payload,
          };
        }),
        sessions,
      ),
    );
    addTearDown(notices.close);
    addTearDown(sessions.dispose);
  }

  final sessions = AudienceTestSessions(
    audienceSession(user: '70000000-0000-4000-8000-000000000001'),
  );
  final posts = _Posts();
  final engagement = _Engagement();
  final _Notices notices;
  final navigator = GlobalKey<NavigatorState>();
  int createdDetailCubits = 0;
  int acknowledgements = 0;
  int ackFailures = 0, lookups = 0;
  Completer<Object?>? ackPending;

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: notices,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [notificationTargetRouteObserver],
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _Notices extends Cubit<NotificationState> implements NotificationCubit {
  _Notices(String recipient, {bool read = true})
    : super(
        const NotificationState.initial().copyWith(
          status: NotificationStatus.success,
          items: [
            AppNotification(
              id: '50000000-0000-4000-8000-000000000001',
              recipientId: recipient,
              type: 'OVERTHINKING_REVEAL_REQUEST_APPROVED',
              title: 'Approved notification',
              message: '',
              read: read,
              createdAt: null,
              payload: const {
                'module': 'OVERTHINKING',
                'action': 'REVEAL_REQUEST_APPROVED',
                'postId': '30000000-0000-4000-8000-000000000001',
                'revealRequestId': '40000000-0000-4000-8000-000000000001',
                'requestStatus': 'APPROVED',
                'sourceEventId': '60000000-0000-4000-8000-000000000001',
                'identityVersion': 1,
              },
            ),
          ],
        ),
      );
  @override
  Future<void> refresh() async {}
  int confirmations = 0;
  @override
  Future<void> applyConfirmedExternalRead(
    AppNotification notification,
    session,
  ) async {
    confirmations++;
  }

  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<void> markAsRead(AppNotification notification) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Posts extends Fake implements OverthinkingRepository {
  final reads = <String>[];
  OverthinkingPost result = _post;
  Completer<Result<OverthinkingPost>>? pending;
  Completer<Result<OverthinkingPost>>? detailPending;
  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    reads.add(postId);
    return (reads.length > 1 ? detailPending?.future : null) ??
        pending?.future ??
        Result.success(result);
  }
}

class _Engagement extends Fake implements EngagementRepository {
  final targets = <String>[];
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    targets.add(targetId);
    return const Result.success(CommentPage(items: [], totalElements: 0));
  }
}
