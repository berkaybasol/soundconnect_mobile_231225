import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_like_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_thread_view.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_comments_sheet.dart';

import 'support/event_audience_fakes.dart';

void main() {
  for (final code in ['9700', '1102', '403', '404']) {
    testWidgets(
      'definitive post rejection $code clears cached comments and composer',
      (tester) async {
        final repository = _Repository();
        await _mount(tester, repository);
        final thread = tester
            .element(find.byType(CommentThreadView))
            .read<CommentThreadCubit>();
        expect(find.text('Yalnızca bu paylaşımın yorumu'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Gönderilmemiş taslak');
        repository.error = AppError(code: code, message: 'Unavailable');
        await thread.load(targetType: 'EVENT_POST', targetId: audiencePostId);
        await tester.pumpAndSettle();
        _expectUnavailable(tester);
        expect(find.text('Gönderilmemiş taslak'), findsNothing);
        expect(thread.isClosed, isTrue);
        expect(repository.writes, 0);
      },
    );
  }

  for (final code in ['network', '503', '9999', '9350', '9353']) {
    testWidgets('recoverable failure $code preserves comments and draft', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(tester, repository);
      final thread = tester
          .element(find.byType(CommentThreadView))
          .read<CommentThreadCubit>();
      await tester.enterText(find.byType(TextField), 'Korunan taslak');
      repository.error = AppError(code: code, message: 'Retry later');
      await thread.load(targetType: 'EVENT_POST', targetId: audiencePostId);
      await tester.pumpAndSettle();
      expect(find.text('Yalnızca bu paylaşımın yorumu'), findsOneWidget);
      expect(find.text('Korunan taslak'), findsOneWidget);
      expect(
        find.byKey(const Key('listener-event-post-comments-unavailable')),
        findsNothing,
      );
      expect(thread.isClosed, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'revocation while sending clears input and prevents stale submission',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await tester.enterText(find.byType(TextField), 'Gönderme denemesi');
      await tester.pump();
      final staleSend = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.send_outlined),
          )
          .onPressed!;
      repository.error = const AppError(code: '9700', message: 'Removed');
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pumpAndSettle();
      _expectUnavailable(tester);
      staleSend();
      await tester.pumpAndSettle();
      expect(repository.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reply rejection invalidates whole post without retaining cached roots',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      final view = tester.widget<CommentThreadView>(
        find.byType(CommentThreadView),
      );
      repository.error = const AppError(code: '9700', message: 'Removed');
      await view.repository!.listReplyPage('root');
      await tester.pumpAndSettle();
      _expectUnavailable(tester);
    },
  );

  testWidgets(
    'comment like rejection invalidates the post and blocks readback retry',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      repository.error = const AppError(code: '9700', message: 'Removed');
      await tester.tap(find.byKey(const ValueKey('comment-like-root')));
      await tester.pumpAndSettle();
      _expectUnavailable(tester);
      expect(repository.likes, 1);
      expect(repository.likeReads, 0);
    },
  );

  testWidgets(
    'feed privacy invalidation removes thread and fences an in-flight response',
    (tester) async {
      final repository = _Repository();
      final available = ValueNotifier(true);
      addTearDown(available.dispose);
      await _mount(tester, repository, available: available);
      final thread = tester
          .element(find.byType(CommentThreadView))
          .read<CommentThreadCubit>();
      final pending = Completer<Result<CommentPage>>();
      repository.pending = pending.future;
      final reload = thread.load(
        targetType: 'EVENT_POST',
        targetId: audiencePostId,
      );
      available.value = false;
      await tester.pumpAndSettle();
      _expectUnavailable(tester);
      pending.complete(Result.success(_page()));
      await reload;
      await tester.pumpAndSettle();
      _expectUnavailable(tester);
      expect(thread.isClosed, isTrue);
    },
  );

  testWidgets(
    'session change wins over simultaneous publication invalidation',
    (tester) async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      final available = ValueNotifier(true);
      addTearDown(sessions.dispose);
      addTearDown(available.dispose);
      await _mount(
        tester,
        repository,
        sessions: sessions,
        available: available,
      );
      await tester.enterText(find.byType(TextField), 'Eski hesabın taslağı');
      available.value = false;
      sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(
        find.text('Oturum değişti. Paylaşımı yeniden açabilirsin.'),
        findsOneWidget,
      );
      expect(find.text('Yalnızca bu paylaşımın yorumu'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard keeps comment composer above the obscured area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _mount(tester, _Repository());
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(400),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rebinding the open publication clears drafts and uses the new repository',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      final first = _Repository();
      final second = _Repository();
      final current = ValueNotifier<_Repository>(first);
      addTearDown(sessions.dispose);
      addTearDown(current.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<_Repository>(
              valueListenable: current,
              builder: (context, repository, _) =>
                  ListenerEventPostCommentsSheet(
                    postId: audiencePostId,
                    repository: repository,
                    sessions: sessions,
                    expectedSession: sessions.session,
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Eski oturumun taslağı');
      current.value = second;
      await tester.pumpAndSettle();
      expect(find.text('Eski oturumun taslağı'), findsNothing);
      expect(find.text('Yalnızca bu paylaşımın yorumu'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Yeni yorum');
      await tester.pump();
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pumpAndSettle();
      expect(first.writes, 0);
      expect(second.writes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

void _expectUnavailable(WidgetTester tester) {
  expect(
    find.byKey(const Key('listener-event-post-comments-unavailable')),
    findsOneWidget,
  );
  expect(find.text('Yalnızca bu paylaşımın yorumu'), findsNothing);
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(CommentThreadView), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  AudienceTestSessions? sessions,
  ValueNotifier<bool>? available,
}) async {
  final manager = sessions ?? AudienceTestSessions(audienceSession());
  if (sessions == null) addTearDown(manager.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: false,
              backgroundColor: const Color(0xFF101722),
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => ListenerEventPostCommentsSheet(
                postId: audiencePostId,
                repository: repository,
                sessions: manager,
                expectedSession: manager.session,
                publicationAvailable: available,
              ),
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await tester.pumpAndSettle();
}

CommentPage _page() =>
    CommentPage(items: [_comment()], totalElements: 1, page: 0, size: 50);

CommentItem _comment() => const CommentItem(
  id: 'root',
  user: CommentUserSummary(id: 'listener', username: 'Berna', avatarUrl: null),
  text: 'Yalnızca bu paylaşımın yorumu',
  deleted: false,
  parentCommentId: null,
  replyCount: 1,
  createdAt: null,
);

class _Repository extends Fake implements EngagementRepository {
  AppError? error;
  Future<Result<CommentPage>>? pending;
  int writes = 0;
  int likes = 0;
  int likeReads = 0;

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async =>
      pending ??
      (error == null ? Result.success(_page()) : Result.failure(error!));

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    writes++;
    return error == null ? Result.success(_comment()) : Result.failure(error!);
  }

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) async => error == null ? Result.success(_page()) : Result.failure(error!);

  @override
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) async {
    likes++;
    return error == null
        ? Result.success(CommentLikeState(likeCount: 1, likedByMe: liked))
        : Result.failure(error!);
  }

  @override
  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) async {
    likeReads++;
    return error == null
        ? const Result.success(CommentLikeState(likeCount: 0, likedByMe: false))
        : Result.failure(error!);
  }
}
