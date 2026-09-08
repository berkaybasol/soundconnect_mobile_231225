import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';

const _error = AppError(code: 'network', message: 'Yüklenemedi.');

void main() {
  late _Repository repository;
  late CommentThreadCubit cubit;
  setUp(() {
    repository = _Repository();
    cubit = CommentThreadCubit(repository);
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test(
    'load keeps existing first-page size and exposes successful comments',
    () async {
      final load = cubit.load(targetType: 'EVENT', targetId: 'a');
      expect(cubit.state.loading, isTrue);
      expect(repository.loadRequests.single, ('EVENT', 'a', 0, 50));
      repository.loads.single.complete(_page('one'));
      await load;
      expect(cubit.state.comments.single.id, 'one');
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
    },
  );

  test('load failure preserves existing same-target comments', () async {
    final first = cubit.load(targetType: 'EVENT', targetId: 'a');
    repository.loads[0].complete(_page('one'));
    await first;
    final second = cubit.load(targetType: 'EVENT', targetId: 'a');
    repository.loads[1].complete(const Result.failure(_error));
    await second;
    expect(cubit.state.comments.single.id, 'one');
    expect(cubit.state.error, same(_error));
    expect(cubit.state.loading, isFalse);
  });

  test(
    'explicit same-target reload clears identity projection and rejects stale load',
    () async {
      final first = cubit.load(targetType: 'EVENT', targetId: 'a');
      repository.loads[0].complete(_page('old-viewer'));
      await first;
      final old = cubit.load(targetType: 'EVENT', targetId: 'a');
      final changedViewer = cubit.load(
        targetType: 'EVENT',
        targetId: 'a',
        clearExisting: true,
      );
      expect(cubit.state.comments, isEmpty);
      expect(cubit.state.loading, isTrue);
      repository.loads[1].complete(_page('stale-viewer'));
      await old;
      expect(cubit.state.comments, isEmpty);
      repository.loads[2].complete(const Result.failure(_error));
      await changedViewer;
      expect(cubit.state.comments, isEmpty);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, same(_error));
    },
  );

  for (final fail in [false, true]) {
    test(
      'late load ${fail ? 'failure' : 'success'} after close cannot emit',
      () async {
        final load = cubit.load(targetType: 'EVENT', targetId: 'a');
        await cubit.close();
        repository.loads.single.complete(
          fail ? const Result.failure(_error) : _page('one'),
        );
        await expectLater(load, completes);
      },
    );
  }

  test('closed cubit does not dispatch new list or create requests', () async {
    await cubit.close();
    await cubit.load(targetType: 'EVENT', targetId: 'a');
    await cubit.create(targetType: 'EVENT', targetId: 'a', text: 'hello');
    expect(repository.loads, isEmpty);
    expect(repository.creates, isEmpty);
  });

  for (final fail in [false, true]) {
    test(
      'older same-target ${fail ? 'error' : 'result'} cannot replace newer load',
      () async {
        final old = cubit.load(targetType: 'EVENT', targetId: 'a');
        final latest = cubit.load(targetType: 'EVENT', targetId: 'a');
        repository.loads[1].complete(_page('new'));
        await latest;
        repository.loads[0].complete(
          fail ? const Result.failure(_error) : _page('old'),
        );
        await old;
        expect(cubit.state.comments.single.id, 'new');
        expect(cubit.state.error, isNull);
      },
    );
  }

  test('new target clears old comments and ignores old target load', () async {
    final first = cubit.load(targetType: 'EVENT', targetId: 'a');
    repository.loads[0].complete(_page('old'));
    await first;
    final old = cubit.load(targetType: 'EVENT', targetId: 'a');
    final latest = cubit.load(targetType: 'MEDIA', targetId: 'b');
    expect(cubit.state.comments, isEmpty);
    repository.loads[2].complete(_page('new'));
    await latest;
    repository.loads[1].complete(_page('stale'));
    await old;
    expect(cubit.state.comments.single.id, 'new');
  });

  test(
    'successful create reloads same target and prevents duplicate create',
    () async {
      final create = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
        parentCommentId: 'root',
      );
      await cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
        parentCommentId: 'root',
      );
      expect(repository.creates, hasLength(1));
      expect(repository.createRequests.single, ('EVENT', 'a', 'hello', 'root'));
      repository.creates[0].complete(Result.success(_comment('created')));
      await Future<void>.delayed(Duration.zero);
      expect(repository.loadRequests.single, ('EVENT', 'a', 0, 50));
      expect(cubit.state.submitting, isTrue);
      repository.loads[0].complete(_page('created'));
      await create;
      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.comments.single.id, 'created');
    },
  );

  test(
    'create failure allows retry and is not replaced by pre-create list',
    () async {
      final old = cubit.load(targetType: 'EVENT', targetId: 'a');
      final create = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
      );
      repository.creates[0].complete(const Result.failure(_error));
      await create;
      repository.loads[0].complete(_page('stale'));
      await old;
      expect(cubit.state.error, same(_error));
      expect(cubit.state.comments, isEmpty);
      expect(cubit.state.submitting, isFalse);
      final retry = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
      );
      expect(repository.creates, hasLength(2));
      repository.creates[1].complete(const Result.failure(_error));
      await retry;
    },
  );

  for (final fail in [false, true]) {
    test(
      'create ${fail ? 'failure' : 'success'} after close cannot emit or reload',
      () async {
        final create = cubit.create(
          targetType: 'EVENT',
          targetId: 'a',
          text: 'hello',
        );
        await cubit.close();
        repository.creates.single.complete(
          fail ? const Result.failure(_error) : Result.success(_comment('new')),
        );
        await expectLater(create, completes);
        expect(repository.loads, isEmpty);
      },
    );
  }

  test('close during successful-create reload is safe', () async {
    final create = cubit.create(
      targetType: 'EVENT',
      targetId: 'a',
      text: 'hello',
    );
    repository.creates[0].complete(Result.success(_comment('new')));
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    repository.loads.single.complete(_page('new'));
    await expectLater(create, completes);
  });

  test(
    'old target create cannot reload or mutate a newly selected target',
    () async {
      final create = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
      );
      final changed = cubit.load(targetType: 'EVENT', targetId: 'b');
      expect(cubit.state.submitting, isFalse);
      repository.loads[0].complete(_page('target-b'));
      await changed;
      repository.creates[0].complete(Result.success(_comment('target-a')));
      await create;
      expect(repository.loads, hasLength(1));
      expect(cubit.state.comments.single.id, 'target-b');
    },
  );

  test(
    'successful-post semantics remain successful when follow-up reload fails',
    () async {
      final create = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
      );
      repository.creates[0].complete(Result.success(_comment('new')));
      await Future<void>.delayed(Duration.zero);
      repository.loads[0].complete(const Result.failure(_error));
      await create;
      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.error, isNull);
    },
  );

  test('unexpected list or create exception releases busy flags', () async {
    repository.throwOnList = true;
    await cubit.load(targetType: 'EVENT', targetId: 'a');
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.error?.code, 'engagement_comments_unknown');
    repository.throwOnCreate = true;
    await cubit.create(targetType: 'EVENT', targetId: 'a', text: 'hello');
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.error?.code, 'engagement_comment_create_unknown');
  });
}

CommentItem _comment(String id) => CommentItem(
  id: id,
  user: const CommentUserSummary(id: 'user', username: 'User', avatarUrl: null),
  text: id,
  deleted: false,
  parentCommentId: null,
  replyCount: 0,
  createdAt: null,
);
Result<CommentPage> _page(String id) =>
    Result.success(CommentPage(items: [_comment(id)], totalElements: 1));

class _Repository extends Fake implements EngagementRepository {
  final loads = <Completer<Result<CommentPage>>>[];
  final creates = <Completer<Result<CommentItem>>>[];
  final loadRequests = <(String, String, int, int)>[];
  final createRequests = <(String, String, String, String?)>[];
  bool throwOnList = false;
  bool throwOnCreate = false;
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) {
    if (throwOnList) throw StateError('offline');
    loadRequests.add((targetType, targetId, page, size));
    final pending = Completer<Result<CommentPage>>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) {
    if (throwOnCreate) throw StateError('offline');
    createRequests.add((targetType, targetId, text, parentCommentId));
    final pending = Completer<Result<CommentItem>>();
    creates.add(pending);
    return pending.future;
  }
}
