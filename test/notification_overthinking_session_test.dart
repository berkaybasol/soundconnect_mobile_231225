import 'dart:async';

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
  'id': 'post',
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
        expect(h.posts.reads, ['post']);

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
      expect(h.posts.reads, ['post', 'post']);
      expect(find.byType(OverthinkingDetailScreen), findsOneWidget);
      expect(find.text(_post.title), findsOneWidget);
      expect(find.text('@approved-author'), findsOneWidget);
      expect(h.engagement.targets, ['post']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Harness {
  _Harness({String recipient = 'owner'}) : notices = _Notices(recipient) {
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
    addTearDown(notices.close);
    addTearDown(sessions.dispose);
  }

  final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
  final posts = _Posts();
  final engagement = _Engagement();
  final _Notices notices;
  final navigator = GlobalKey<NavigatorState>();
  int createdDetailCubits = 0;

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: notices,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _Notices extends Cubit<NotificationState> implements NotificationCubit {
  _Notices(String recipient)
    : super(
        const NotificationState.initial().copyWith(
          status: NotificationStatus.success,
          items: [
            AppNotification(
              id: 'notice',
              recipientId: recipient,
              type: 'OVERTHINKING_REVEAL_REQUEST_APPROVED',
              title: 'Approved notification',
              message: '',
              read: true,
              createdAt: null,
              payload: const {'module': 'OVERTHINKING', 'postId': 'post'},
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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Posts extends Fake implements OverthinkingRepository {
  final reads = <String>[];
  Completer<Result<OverthinkingPost>>? pending;
  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    reads.add(postId);
    return pending?.future ?? Result.success(_post);
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
