import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_thread_view.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_comments_sheet.dart';

import 'support/event_audience_fakes.dart';

const _sourceId = '35f9719a-ae8a-4d93-86f7-9bdd5aa31511';
const _shareId = '5e36e411-0e6a-4575-8e68-88aee7072cbd';

void main() {
  testWidgets('shared writing lists and creates the source thread', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    expect(repository.reads.single, ('OVERTHINKING', _sourceId));
    expect(
      find.byKey(const Key('listener-overthinking-comments-panel')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Asıl yazıya yeni yorum');
    await tester.pump();
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pumpAndSettle();
    expect(repository.writes.single, (
      'OVERTHINKING',
      _sourceId,
      'Asıl yazıya yeni yorum',
    ));
    expect(repository.reads.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source scope rejects a share ID and EVENT_POST operations', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    final scoped = _scoped(tester);
    for (final scope in [
      ('OVERTHINKING', _shareId),
      ('EVENT_POST', _sourceId),
    ]) {
      final result = await scoped.createComment(
        targetType: scope.$1,
        targetId: scope.$2,
        text: 'Wrong thread',
      );
      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'overthinking_comment_scope_invalid');
    }
    expect(repository.writes, isEmpty);
    expect(find.byType(CommentThreadView), findsOneWidget);
  });

  for (final code in ['9401', '9700', '1102', '403', '404', '410']) {
    testWidgets('source rejection $code removes comments and draft', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await tester.enterText(find.byType(TextField), 'Kaldırılacak taslak');
      final thread = _thread(tester);
      repository.error = AppError(code: code, message: 'Source unavailable');
      await thread.load(targetType: 'OVERTHINKING', targetId: _sourceId);
      await tester.pumpAndSettle();
      _expectUnavailable(tester);
      expect(thread.isClosed, isTrue);
      expect(find.text('Kaldırılacak taslak'), findsNothing);
    });
  }

  for (final code in ['9350', '9353', '9355', '403', '404', '410', '503']) {
    testWidgets('individual comment rejection $code preserves source draft', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await tester.enterText(find.byType(TextField), 'Korunan taslak');
      repository.error = AppError(code: code, message: 'Comment unavailable');
      final result = await _scoped(tester).listReplyPage('removed-comment');
      await tester.pumpAndSettle();
      expect(result.isSuccess, isFalse);
      expect(find.text('Asıl yazıdaki yorum'), findsOneWidget);
      expect(find.text('Korunan taslak'), findsOneWidget);
      expect(_thread(tester).isClosed, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('source rejection during a reply revokes every cached root', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    repository.error = const AppError(code: '9700', message: 'Source gone');
    await _scoped(tester).listReplyPage('comment');
    await tester.pumpAndSettle();
    _expectUnavailable(tester);
  });

  for (final changeSession in [false, true]) {
    testWidgets(
      '${changeSession ? 'session' : 'publication'} invalidation fences pending reads and stale writes',
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
        final scoped = _scoped(tester);
        final thread = _thread(tester);
        final pending = Completer<Result<CommentPage>>();
        repository.pending = pending.future;
        final loading = thread.load(
          targetType: 'OVERTHINKING',
          targetId: _sourceId,
        );
        if (changeSession) {
          sessions.replace(audienceSession(user: 'other'));
        } else {
          available.value = false;
        }
        await tester.pumpAndSettle();
        pending.complete(Result.success(_page));
        await loading;
        final staleWrite = await scoped.createComment(
          targetType: 'OVERTHINKING',
          targetId: _sourceId,
          text: 'Eski ekrandan gönderme',
        );
        await tester.pumpAndSettle();
        expect(staleWrite.isSuccess, isFalse);
        expect(repository.writes, isEmpty);
        expect(thread.isClosed, isTrue);
        expect(find.byType(CommentThreadView), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Asıl yazıdaki yorum'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

EngagementRepository _scoped(WidgetTester tester) => tester
    .widget<CommentThreadView>(find.byType(CommentThreadView))
    .repository!;

CommentThreadCubit _thread(WidgetTester tester) =>
    tester.element(find.byType(CommentThreadView)).read<CommentThreadCubit>();

void _expectUnavailable(WidgetTester tester) {
  expect(
    find.byKey(const Key('listener-overthinking-comments-unavailable')),
    findsOneWidget,
  );
  expect(find.text('Bu yazı artık görüntülenemiyor.'), findsOneWidget);
  expect(find.byType(CommentThreadView), findsNothing);
  expect(find.byType(TextField), findsNothing);
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
        body: ListenerEventPostCommentsSheet.overthinking(
          postId: _sourceId,
          repository: repository,
          sessions: manager,
          expectedSession: manager.session,
          publicationAvailable: available,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _comment = CommentItem(
  id: 'comment',
  user: CommentUserSummary(id: 'listener', username: 'Berna', avatarUrl: null),
  text: 'Asıl yazıdaki yorum',
  deleted: false,
  parentCommentId: null,
  replyCount: 1,
  createdAt: null,
);
const _page = CommentPage(
  items: [_comment],
  totalElements: 1,
  page: 0,
  size: 50,
);

class _Repository extends Fake implements EngagementRepository {
  final reads = <(String, String)>[];
  final writes = <(String, String, String)>[];
  AppError? error;
  Future<Result<CommentPage>>? pending;

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    reads.add((targetType, targetId));
    return pending ??
        (error == null ? const Result.success(_page) : Result.failure(error!));
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    writes.add((targetType, targetId, text));
    return error == null
        ? const Result.success(_comment)
        : Result.failure(error!);
  }

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) async =>
      error == null ? const Result.success(_page) : Result.failure(error!);
}
