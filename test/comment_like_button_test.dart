import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_like_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_like_button.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_like_memory.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'support/event_audience_fakes.dart';

void main() {
  late _Likes repository;
  late AudienceTestSessions sessions;
  setUp(() {
    repository = _Likes();
    sessions = AudienceTestSessions(audienceSession());
  });
  Future<void> open(
    WidgetTester tester, {
    CommentItem? item,
    bool compact = false,
    bool enabled = true,
    bool Function()? current,
    double scale = 1,
    CommentLikeMemory? memory,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: CommentLikeButton(
                  comment: item ?? _item,
                  repository: repository,
                  sessions: sessions,
                  isCurrent: current ?? () => true,
                  compact: compact,
                  enabled: enabled,
                  memory: memory,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder button([String id = 'comment']) =>
      find.byKey(ValueKey('comment-like-$id'));

  testWidgets('folding/remount retains confirmed like without an extra GET', (
    tester,
  ) async {
    final memory = CommentLikeMemory();
    repository.onWrite = (_, _) async =>
        const Result.success(CommentLikeState(likeCount: 8, likedByMe: true));
    await open(tester, memory: memory);
    await tester.tap(button());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, memory: memory);
    expect(find.byTooltip('Beğeniyi kaldır'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(repository.reads, isEmpty);
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(repository.writes.last, ('comment', false));
  });

  testWidgets(
    'remount during write shares single flight and receives completion',
    (tester) async {
      final memory = CommentLikeMemory();
      final pending = Completer<Result<CommentLikeState>>();
      repository.onWrite = (_, _) => pending.future;
      await open(tester, memory: memory);
      await tester.tap(button());
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, memory: memory);
      expect(tester.widget<TextButton>(button()).onPressed, isNull);
      pending.complete(
        const Result.success(CommentLikeState(likeCount: 8, likedByMe: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      expect(find.byTooltip('Beğeniyi kaldır'), findsOneWidget);
      expect(repository.writes, hasLength(1));
      expect(repository.reads, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('thread close invalidates a pending write projection', (
    tester,
  ) async {
    final memory = CommentLikeMemory();
    final pending = Completer<Result<CommentLikeState>>();
    repository.onWrite = (_, _) => pending.future;
    await open(tester, memory: memory);
    await tester.tap(button());
    await tester.pumpWidget(const SizedBox.shrink());
    memory.clear();
    pending.complete(
      const Result.success(CommentLikeState(likeCount: 8, likedByMe: true)),
    );
    await tester.pump();
    await open(tester, memory: memory);
    expect(find.text('7'), findsOneWidget);
    expect(find.byTooltip('Beğeniyi kaldır'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page projection needs no per-row GET and write returns exact count',
    (tester) async {
      await open(tester);
      expect(repository.reads, isEmpty);
      expect(repository.writes, isEmpty);
      expect(find.text('7'), findsOneWidget);
      final pending = Completer<Result<CommentLikeState>>();
      repository.onWrite = (_, _) => pending.future;
      final action = tester.widget<TextButton>(button()).onPressed!;
      action();
      action();
      await tester.pump();
      expect(repository.writes, [('comment', true)]);
      expect(find.text('7'), findsOneWidget); // No invented optimistic total.
      pending.complete(
        const Result.success(CommentLikeState(likeCount: 12, likedByMe: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
      expect(find.byTooltip('Beğeniyi kaldır'), findsOneWidget);
      repository.onWrite = (_, _) async => const Result.success(
        CommentLikeState(likeCount: 11, likedByMe: false),
      );
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(repository.writes, [('comment', true), ('comment', false)]);
      expect(repository.reads, isEmpty);
      expect(find.text('11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uncertain write is read back once without automatic write retry',
    (tester) async {
      repository.onWrite = (_, _) async => const Result.failure(_offline);
      repository.onRead = (_) async =>
          const Result.success(CommentLikeState(likeCount: 8, likedByMe: true));
      await open(tester);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(repository.writes, [('comment', true)]);
      expect(repository.reads, ['comment']);
      expect(find.byTooltip('Beğeniyi kaldır'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'unresolved state requires a read-only refresh before another write',
    (tester) async {
      repository.onWrite = (_, _) async => const Result.failure(_offline);
      repository.onRead = (_) async => const Result.failure(_offline);
      await open(tester);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Beğeni durumunu yenile'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      repository.onRead = (_) async =>
          const Result.success(CommentLikeState(likeCount: 8, likedByMe: true));
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(repository.writes, [('comment', true)]);
      expect(repository.reads, ['comment', 'comment']);
      expect(find.byTooltip('Beğeniyi kaldır'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.writes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retained gesture cannot write under a replacement account', (
    tester,
  ) async {
    await open(tester);
    final old = tester.widget<TextButton>(button()).onPressed!;
    sessions.replace(audienceSession(user: 'other', token: 'other'));
    await tester.pump();
    old();
    await tester.pump();
    expect(repository.writes, isEmpty);
    expect(repository.reads, isEmpty);
  });

  testWidgets('silent account change rejects stale dispatch and completion', (
    tester,
  ) async {
    final pending = Completer<Result<CommentLikeState>>();
    repository.onWrite = (_, _) => pending.future;
    await open(tester);
    final old = tester.widget<TextButton>(button()).onPressed!;
    old();
    await tester.pump();
    sessions.current = audienceSession(user: 'other', token: 'other');
    old();
    pending.complete(
      const Result.success(CommentLikeState(likeCount: 99, likedByMe: true)),
    );
    await tester.pump();
    expect(repository.writes, hasLength(1));
    expect(find.text('99'), findsNothing);
    expect(repository.reads, isEmpty);
    sessions.notifyListeners();
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(button()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changed comment instance invalidates pending state and old gesture',
    (tester) async {
      final pending = Completer<Result<CommentLikeState>>();
      repository.onWrite = (_, _) => pending.future;
      await open(tester);
      final old = tester.widget<TextButton>(button()).onPressed!;
      old();
      await tester.pump();
      await open(tester, item: _comment(count: 30));
      pending.complete(
        const Result.success(CommentLikeState(likeCount: 8, likedByMe: true)),
      );
      await tester.pumpAndSettle();
      old();
      await tester.pump();
      expect(find.text('30'), findsOneWidget);
      expect(find.text('8'), findsNothing);
      expect(repository.writes, hasLength(1));
    },
  );

  testWidgets(
    'temporary disable does not leave completed like permanently busy',
    (tester) async {
      final pending = Completer<Result<CommentLikeState>>();
      repository.onWrite = (_, _) => pending.future;
      await open(tester);
      await tester.tap(button());
      await tester.pump();
      await open(tester, enabled: false);
      pending.complete(
        const Result.success(CommentLikeState(likeCount: 8, likedByMe: true)),
      );
      await tester.pumpAndSettle();
      await open(tester);
      expect(tester.widget<TextButton>(button()).onPressed, isNotNull);
      expect(find.text('8'), findsOneWidget);
    },
  );

  for (final session in [
    const AuthSession.guest(),
    audienceSession(status: 'INACTIVE'),
  ]) {
    testWidgets(
      'unavailable account cannot mutate a comment ${session.accountStatus}',
      (tester) async {
        sessions.current = session;
        await open(tester);
        expect(tester.widget<TextButton>(button()).onPressed, isNull);
        expect(repository.reads, isEmpty);
        expect(repository.writes, isEmpty);
      },
    );
  }
  testWidgets('deleted comment has no heart or counts', (tester) async {
    await open(tester, item: _comment(deleted: true));
    expect(button(), findsNothing);
    expect(repository.reads, isEmpty);
  });
  testWidgets('retained inactive row gesture is ignored', (tester) async {
    var current = true;
    await open(tester, current: () => current);
    final action = tester.widget<TextButton>(button()).onPressed!;
    current = false;
    action();
    await tester.pump();
    expect(repository.writes, isEmpty);
  });
  testWidgets('compact large count is bounded and accessible at doubled text', (
    tester,
  ) async {
    await open(tester, item: _comment(count: 1234567), compact: true, scale: 2);
    expect(tester.getSize(button()).width, lessThanOrEqualTo(250));
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel('Beğen, 1234567 beğeni'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}

const _offline = AppError(code: 'network', message: 'Bağlantı yok.');
const _item = CommentItem(
  id: 'comment',
  user: CommentUserSummary(id: 'writer', username: 'berna', avatarUrl: null),
  text: 'Yorum',
  deleted: false,
  parentCommentId: null,
  replyCount: 0,
  createdAt: null,
  likeCount: 7,
);
CommentItem _comment({int count = 7, bool deleted = false}) => CommentItem(
  id: 'comment',
  user: _item.user,
  text: 'Yorum',
  deleted: deleted,
  parentCommentId: null,
  replyCount: 0,
  createdAt: null,
  likeCount: count,
);

class _Likes extends Fake implements EngagementRepository {
  final writes = <(String, bool)>[];
  final reads = <String>[];
  Future<Result<CommentLikeState>> Function(String, bool)? onWrite;
  Future<Result<CommentLikeState>> Function(String)? onRead;
  @override
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) async {
    writes.add((commentId, liked));
    return onWrite?.call(commentId, liked) ??
        Result.success(
          CommentLikeState(likeCount: liked ? 8 : 7, likedByMe: liked),
        );
  }

  @override
  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) async {
    reads.add(commentId);
    return onRead?.call(commentId) ??
        const Result.success(CommentLikeState(likeCount: 7, likedByMe: false));
  }
}
