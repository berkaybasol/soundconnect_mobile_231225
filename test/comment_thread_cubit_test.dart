import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';

import 'support/event_audience_fakes.dart';

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
      expect(cubit.state.lastCreated!.id, 'new');
      expect(cubit.state.reloadError, same(_error));
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

  test(
    'null successful POST payload is not treated as a confirmed write',
    () async {
      final write = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
      );
      repository.creates.single.complete(const Result.success(null));
      expect(await write, isFalse);
      expect(repository.loads, isEmpty);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.submitting, isFalse);
    },
  );

  test('blank and too-long text cannot dispatch or change target', () async {
    for (final text in ['  ', '😀' * 251]) {
      expect(
        await cubit.create(targetType: 'EVENT', targetId: 'a', text: text),
        isFalse,
      );
    }
    expect(repository.creates, isEmpty);
  });

  test(
    'loadMore is single-flight, deduplicates rows and retries the failed page',
    () async {
      final first = cubit.load(targetType: 'EVENT', targetId: 'a');
      repository.loads[0].complete(
        Result.success(
          CommentPage(items: [_comment('one')], totalElements: 101),
        ),
      );
      await first;
      expect(cubit.state.hasMore, isTrue);
      final second = cubit.loadMore();
      await cubit.loadMore();
      expect(repository.loadRequests[1], ('EVENT', 'a', 1, 50));
      expect(repository.loads, hasLength(2));
      repository.loads[1].complete(const Result.failure(_error));
      await second;
      expect(cubit.state.comments.single.id, 'one');
      expect(cubit.state.hasMore, isTrue);
      final retry = cubit.loadMore();
      expect(repository.loadRequests[2].$3, 1);
      repository.loads[2].complete(
        Result.success(
          CommentPage(
            items: [_comment('one'), _comment('two')],
            totalElements: 101,
          ),
        ),
      );
      await retry;
      expect(cubit.state.comments.map((item) => item.id), ['one', 'two']);
      final last = cubit.loadMore();
      repository.loads[3].complete(
        Result.success(
          CommentPage(items: [_comment('three')], totalElements: 101),
        ),
      );
      await last;
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.totalElements, 101);
      expect(() => cubit.state.comments.clear(), throwsUnsupportedError);
    },
  );

  test(
    'refresh invalidates a pending append before it can mix pages',
    () async {
      final first = cubit.load(targetType: 'EVENT', targetId: 'a');
      repository.loads[0].complete(
        Result.success(
          CommentPage(items: [_comment('one')], totalElements: 60),
        ),
      );
      await first;
      final more = cubit.loadMore();
      final refresh = cubit.load(targetType: 'EVENT', targetId: 'a');
      repository.loads[2].complete(_page('fresh'));
      await refresh;
      repository.loads[1].complete(_page('stale-more'));
      await more;
      expect(cubit.state.comments.single.id, 'fresh');
    },
  );

  for (final target in ['EVENT', 'MEDIA', 'OVERTHINKING_POST']) {
    test(
      '$target 400 roots load in eight explicit pages and retry the same failed page',
      () async {
        final rows = List.generate(400, (index) => _comment('root-$index'));
        var request = 0;
        for (var page = 0; page < 8; page++) {
          var pending = page == 0
              ? cubit.load(targetType: target, targetId: 'target')
              : cubit.loadMore();
          expect(repository.loadRequests.last, (target, 'target', page, 50));
          if (page > 0) {
            await cubit.loadMore();
            expect(repository.loads.length, request + 1);
          }
          if (page == 3) {
            repository.loads[request++].complete(const Result.failure(_error));
            await pending;
            expect(cubit.state.comments, hasLength(150));
            expect(cubit.state.error, same(_error));
            expect(cubit.state.hasMore, isTrue);
            pending = cubit.loadMore();
            expect(repository.loadRequests.last, (target, 'target', 3, 50));
          }
          repository.loads[request++].complete(
            Result.success(
              CommentPage(
                items: rows.skip(page * 50).take(50).toList(),
                totalElements: 400,
                page: page,
                size: 50,
              ),
            ),
          );
          await pending;
          expect(cubit.state.comments, hasLength((page + 1) * 50));
          expect(cubit.state.totalElements, 400);
          expect(cubit.state.hasMore, page < 7);
          expect(cubit.state.error, isNull);
          expect(repository.loads.length, request);
        }
        expect(
          cubit.state.comments.map((row) => row.id),
          rows.map((row) => row.id),
        );
        expect(repository.loadRequests.map((request) => request.$3), [
          0,
          1,
          2,
          3,
          3,
          4,
          5,
          6,
          7,
        ]);
        await cubit.loadMore();
        expect(repository.loads, hasLength(9));
      },
    );
  }

  test(
    'live front insertion can produce an all-duplicate page without ending pagination',
    () async {
      final original = List.generate(400, (index) => _comment('root-$index'));
      final first = cubit.load(targetType: 'EVENT', targetId: 'target');
      repository.loads.single.complete(
        Result.success(
          CommentPage(
            items: original.take(50).toList(),
            totalElements: 400,
            size: 50,
          ),
        ),
      );
      await first;
      final currentServerRows = [
        ...List.generate(50, (index) => _comment('inserted-$index')),
        ...original,
      ];
      for (var page = 1; page <= 8; page++) {
        final next = cubit.loadMore();
        expect(repository.loadRequests.last.$3, page);
        repository.loads.last.complete(
          Result.success(
            CommentPage(
              items: currentServerRows.skip(page * 50).take(50).toList(),
              totalElements: 450,
              page: page,
              size: 50,
            ),
          ),
        );
        await next;
        expect(cubit.state.comments.length, page * 50);
        expect(cubit.state.hasMore, page < 8);
        expect(cubit.state.error, isNull);
      }
      expect(
        cubit.state.comments.map((row) => row.id),
        original.map((row) => row.id),
      );
      expect(cubit.state.totalElements, 450);
      await cubit.loadMore();
      expect(repository.loads, hasLength(9));
      // Offset pagination does not backfill newly inserted leading rows until
      // refresh. It must still make every original row reachable without repeats.
    },
  );

  test(
    'a newer overlapping deleted projection replaces stale text without reordering roots',
    () async {
      final original = List.generate(100, (index) => _comment('root-$index'));
      final first = cubit.load(targetType: 'EVENT', targetId: 'target');
      repository.loads.single.complete(
        Result.success(
          CommentPage(
            items: original.take(50).toList(),
            totalElements: 100,
            size: 50,
          ),
        ),
      );
      await first;
      final deleted = CommentItem(
        id: 'root-49',
        user: original[49].user,
        text: '',
        deleted: true,
        parentCommentId: null,
        replyCount: 0,
        createdAt: null,
      );
      final next = cubit.loadMore();
      repository.loads.last.complete(
        Result.success(
          CommentPage(
            items: [deleted, ...original.skip(50).take(49)],
            totalElements: 101,
            page: 1,
            size: 50,
          ),
        ),
      );
      await next;
      expect(cubit.state.comments, hasLength(99));
      expect(cubit.state.comments[49], same(deleted));
      expect(cubit.state.comments[49].text, isEmpty);
      expect(cubit.state.comments.first, same(original.first));
      expect(
        cubit.state.comments.map((row) => row.id),
        original.take(99).map((row) => row.id),
      );
      expect(cubit.state.hasMore, isTrue);
    },
  );

  test(
    'a valid empty page after the total shrinks stops without another request',
    () async {
      final first = cubit.load(targetType: 'EVENT', targetId: 'target');
      repository.loads.single.complete(
        Result.success(
          CommentPage(
            items: List.generate(50, (index) => _comment('root-$index')),
            totalElements: 400,
            size: 50,
          ),
        ),
      );
      await first;
      final next = cubit.loadMore();
      repository.loads.last.complete(
        const Result.success(
          CommentPage(items: [], totalElements: 50, page: 1, size: 50),
        ),
      );
      await next;
      expect(cubit.state.comments, hasLength(50));
      expect(cubit.state.totalElements, 50);
      expect(cubit.state.hasMore, isFalse);
      await cubit.loadMore();
      expect(repository.loads, hasLength(2));
    },
  );

  test(
    'same-target identity reset invalidates pending POST without a session dependency',
    () async {
      final create = cubit.create(
        targetType: 'EVENT',
        targetId: 'a',
        text: 'hello',
      );
      final refresh = cubit.load(
        targetType: 'EVENT',
        targetId: 'a',
        clearExisting: true,
      );
      repository.loads.single.complete(_page('new-viewer'));
      await refresh;
      repository.creates.single.complete(
        Result.success(_comment('old-viewer')),
      );
      expect(await create, isFalse);
      expect(repository.loads, hasLength(1));
      expect(cubit.state.comments.single.id, 'new-viewer');
    },
  );

  test(
    'session switch clears state and pending create cannot reload previous identity',
    () async {
      await cubit.close();
      final sessions = AudienceTestSessions(audienceSession());
      cubit = CommentThreadCubit(repository, sessions: sessions);
      final write = cubit.create(
        targetType: 'MEDIA',
        targetId: 'a',
        text: 'hello',
      );
      sessions.replace(const AuthSession.guest());
      expect(cubit.state.comments, isEmpty);
      expect(cubit.state.submitting, isFalse);
      repository.creates.single.complete(Result.success(_comment('old')));
      expect(await write, isFalse);
      expect(repository.loads, isEmpty);
      expect(
        await cubit.create(targetType: 'MEDIA', targetId: 'a', text: 'guest'),
        isFalse,
      );
      expect(repository.creates, hasLength(1));
    },
  );

  test(
    'delete failure preserves rows; confirmed deletion reports reload failure separately',
    () async {
      final first = cubit.load(targetType: 'EVENT', targetId: 'a');
      repository.loads.single.complete(_page('one'));
      await first;
      final failed = cubit.delete(commentId: 'one');
      expect(cubit.state.deletingCommentId, 'one');
      expect(await cubit.delete(commentId: 'one'), isFalse);
      repository.deletes[0].complete(const Result.failure(_error));
      expect(await failed, isFalse);
      expect(cubit.state.comments.single.id, 'one');
      final success = cubit.delete(commentId: 'one');
      repository.deletes[1].complete(const Result.success(null));
      await Future<void>.delayed(Duration.zero);
      repository.loads[1].complete(const Result.failure(_error));
      expect(await success, isTrue);
      expect(cubit.state.deletingCommentId, isNull);
      expect(cubit.state.error, isNull);
      expect(cubit.state.reloadError, same(_error));
      expect(cubit.state.comments.single.deleted, isTrue);
      expect(cubit.state.comments.single.text, isEmpty);
    },
  );

  test(
    'retained create cannot select its old target again after thread change',
    () async {
      final selected = cubit.load(targetType: 'EVENT', targetId: 'current');
      repository.loads.single.complete(_page('current-comment'));
      await selected;
      expect(
        await cubit.create(targetType: 'EVENT', targetId: 'old', text: 'stale'),
        isFalse,
      );
      expect(repository.creates, isEmpty);
      expect(cubit.state.comments.single.id, 'current-comment');
    },
  );
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
  final deletes = <Completer<Result<void>>>[];
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

  @override
  Future<Result<void>> deleteComment({required String commentId}) {
    final pending = Completer<Result<void>>();
    deletes.add(pending);
    return pending.future;
  }
}
