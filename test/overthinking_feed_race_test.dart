import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_state.dart';

const _offline = AppError(code: 'offline', message: 'Offline');

void main() {
  test('a late older refresh cannot replace the latest feed', () async {
    final h = _Harness();
    final older = h.cubit.load();
    final latest = h.cubit.load();
    h.repository.feeds[1].complete(_page([_post('fresh')]));
    await latest;
    h.repository.feeds[0].complete(_page([_post('old')], hasNext: true));
    await older;

    expect(h.ids, ['fresh']);
    expect(h.cubit.state.hasNext, isFalse);
    expect(h.cubit.state.status, OverthinkingFeedStatus.idle);
  });

  test(
    'refresh invalidates an older pending next page and its error',
    () async {
      for (final fail in [false, true]) {
        final h = _Harness();
        await h.seed([_post('first')], hasNext: true);
        final more = h.cubit.loadMore();
        final refresh = h.cubit.load();
        h.repository.feeds[2].complete(_page([_post('fresh')]));
        await refresh;
        h.repository.feeds[1].complete(
          fail ? const Result.failure(_offline) : _page([_post('stale-page')]),
        );
        await more;

        expect(h.ids, ['fresh']);
        expect(h.cubit.state.page, 0);
        expect(h.cubit.state.status, OverthinkingFeedStatus.idle);
        expect(h.cubit.state.error, isNull);
      }
    },
  );

  test(
    'pagination removes duplicate IDs from shifting page boundaries',
    () async {
      final h = _Harness();
      await h.seed([_post('a'), _post('b')], hasNext: true);
      final operation = h.cubit.loadMore();
      h.repository.feeds.last.complete(
        _page([_post('b'), _post('c'), _post('c')]),
      );
      await operation;

      expect(h.ids, ['a', 'b', 'c']);
      expect(h.cubit.state.page, 1);
    },
  );

  test(
    'double submit writes once and an older feed keeps the created post',
    () async {
      final h = _Harness();
      final loading = h.cubit.load();
      final creating = h.create();
      expect(await h.create(), isFalse);
      expect(h.repository.creates, hasLength(1));
      h.repository.creates.single.complete(Result.success(_post('created')));
      expect(await creating, isTrue);
      h.repository.feeds.single.complete(_page([_post('old')]));
      await loading;

      expect(h.ids, ['created', 'old']);
      expect(h.cubit.state.submitting, isFalse);
    },
  );

  test('a stale detail cannot undo a confirmed update', () async {
    final h = _Harness();
    final original = _post('a');
    await h.seed([original]);
    final detail = h.cubit.refreshPost('a');
    final update = h.update(original);
    expect(await h.update(original), isFalse);
    expect(await h.cubit.deletePost('a'), isFalse);
    h.repository.updates.single.complete(
      Result.success(original.copyWith(title: 'edited')),
    );
    await update;
    h.repository.details.single.complete(Result.success(original));
    await detail;

    expect(h.cubit.state.posts.single.title, 'edited');
    expect(h.repository.updates, hasLength(1));
    expect(h.repository.deletes, isEmpty);
  });

  test('only the latest detail request can update a post', () async {
    final h = _Harness();
    await h.seed([_post('a')]);
    final first = h.cubit.refreshPost('a');
    final second = h.cubit.refreshPost('a');
    h.repository.details[1].complete(
      Result.success(_post('a').copyWith(title: 'latest')),
    );
    await second;
    h.repository.details[0].complete(Result.success(_post('a')));
    await first;
    expect(h.cubit.state.posts.single.title, 'latest');
  });

  test(
    'late detail, feed and failed like cannot resurrect a deleted post',
    () async {
      final h = _Harness();
      final original = _post('a');
      await h.seed([original]);
      final detail = h.cubit.refreshPost('a');
      final loading = h.cubit.load();
      final liking = h.cubit.toggleLike(original);
      final deleting = h.cubit.deletePost('a');
      expect(await h.cubit.deletePost('a'), isFalse);
      h.repository.deletes.single.complete(const Result.success(null));
      expect(await deleting, isTrue);
      h.repository.details.single.complete(Result.success(original));
      h.repository.feeds.last.complete(_page([original]));
      h.engagement.calls.single.result.complete(const Result.failure(_offline));
      await Future.wait([detail, loading, liking]);

      expect(h.ids, isEmpty);
      expect(h.cubit.state.error, isNull);
      await h.cubit.toggleLike(original);
      await h.cubit.refreshPost('a');
      expect(h.engagement.calls, hasLength(1));
      expect(h.repository.details, hasLength(1));
    },
  );

  test(
    'failed like restores only the like while preserving edited content and comments',
    () async {
      final h = _Harness();
      final original = _post('a');
      await h.seed([original]);
      final liking = h.cubit.toggleLike(original);
      final updating = h.update(original);
      h.cubit.incrementCommentCount('a');
      h.repository.updates.single.complete(
        Result.success(original.copyWith(title: 'edited')),
      );
      await updating;
      h.engagement.calls.single.result.complete(const Result.failure(_offline));
      await liking;

      final post = h.cubit.state.posts.single;
      expect(post.title, 'edited');
      expect(post.commentCount, 1);
      expect(post.likedByMe, isFalse);
      expect(post.likeCount, 0);
      expect(h.cubit.state.error, same(_offline));
    },
  );

  test(
    'one post has only one pending like and later taps use current state',
    () async {
      final h = _Harness();
      final original = _post('a');
      await h.seed([original]);
      final liking = h.cubit.toggleLike(original);
      await h.cubit.toggleLike(h.cubit.state.posts.single);
      expect(h.engagement.calls, hasLength(1));
      h.engagement.calls.single.result.complete(const Result.success(null));
      await liking;

      // A retained widget can still pass its original DTO after the state changed.
      final unliking = h.cubit.toggleLike(original);
      expect(h.engagement.calls.last.liked, isFalse);
      h.engagement.calls.last.result.complete(const Result.success(null));
      await unliking;
      expect(h.cubit.state.posts.single.likedByMe, isFalse);
      expect(h.cubit.state.posts.single.likeCount, 0);
    },
  );

  test('different posts can be liked independently', () async {
    final h = _Harness();
    await h.seed([_post('a'), _post('b')]);
    final a = h.cubit.toggleLike(h.cubit.state.posts[0]);
    final b = h.cubit.toggleLike(h.cubit.state.posts[1]);
    expect(h.engagement.calls, hasLength(2));
    h.engagement.calls[0].result.complete(const Result.success(null));
    h.engagement.calls[1].result.complete(const Result.failure(_offline));
    await Future.wait([a, b]);
    expect(h.cubit.state.posts[0].likedByMe, isTrue);
    expect(h.cubit.state.posts[1].likedByMe, isFalse);
  });

  test('reads begun during a like keep its confirmed result', () async {
    final h = _Harness();
    final original = _post('a');
    await h.seed([original]);
    final liking = h.cubit.toggleLike(original);
    final loading = h.cubit.load();
    final detail = h.cubit.refreshPost('a');
    h.engagement.calls.single.result.complete(const Result.success(null));
    await liking;
    h.repository.feeds.last.complete(_page([original]));
    h.repository.details.single.complete(Result.success(original));
    await Future.wait([loading, detail]);
    expect(h.cubit.state.posts.single.likedByMe, isTrue);
    expect(h.cubit.state.posts.single.likeCount, 1);
  });

  for (final read in ['feed', 'detail']) {
    test('$read applies a fresh anonymity mask despite a local like', () async {
      final h = _Harness();
      final original = _post('a').copyWith(authorAvatarUrl: 'old-avatar');
      await h.seed([original]);
      final reading = read == 'feed'
          ? h.cubit.load()
          : h.cubit.refreshPost('a');
      final liking = h.cubit.toggleLike(original);
      final masked = original.copyWith(
        anonymous: true,
        visibilityType: 'ANONYMOUS',
        canViewAuthor: false,
        authorId: null,
        authorUsername: 'Anonymous',
        authorAvatarUrl: null,
      );
      if (read == 'feed') {
        h.repository.feeds.last.complete(_page([masked]));
      } else {
        h.repository.details.single.complete(Result.success(masked));
      }
      await reading;
      var current = h.cubit.state.posts.single;
      expect(current.hasVisibleAuthor, isFalse);
      expect(current.authorId, isNull);
      expect(current.authorUsername, 'Anonymous');
      expect(current.authorAvatarUrl, isNull);
      expect(current.likedByMe, isTrue);
      h.engagement.calls.single.result.complete(const Result.failure(_offline));
      await liking;
      current = h.cubit.state.posts.single;
      expect(current.hasVisibleAuthor, isFalse);
      expect(current.authorId, isNull);
      expect(current.likedByMe, isFalse);
    });

    test('$read keeps a newer confirmed owner visibility edit', () async {
      final h = _Harness();
      final original = _post('a');
      await h.seed([original]);
      final reading = read == 'feed'
          ? h.cubit.load()
          : h.cubit.refreshPost('a');
      final update = h.cubit.updatePost(
        post: original,
        title: 'edited',
        content: 'edited body',
        anonymous: true,
      );
      final edited = original.copyWith(
        title: 'edited',
        anonymous: true,
        visibilityType: 'ANONYMOUS',
      );
      h.repository.updates.single.complete(Result.success(edited));
      await update;
      if (read == 'feed') {
        h.repository.feeds.last.complete(_page([original]));
      } else {
        h.repository.details.single.complete(Result.success(original));
      }
      await reading;
      final current = h.cubit.state.posts.single;
      expect(current.title, 'edited');
      expect(current.anonymous, isTrue);
      expect(current.visibilityType, 'ANONYMOUS');
      expect(current.canViewAuthor, isTrue);
    });
  }

  test(
    'an older feed cannot undo identity masking from a newer detail read',
    () async {
      final h = _Harness();
      final original = _post('a');
      await h.seed([original]);
      final feed = h.cubit.load();
      final detail = h.cubit.refreshPost('a');
      final masked = original.copyWith(
        anonymous: true,
        visibilityType: 'ANONYMOUS',
        canViewAuthor: false,
        authorId: null,
        authorUsername: 'Anonymous',
      );
      h.repository.details.single.complete(Result.success(masked));
      await detail;
      h.repository.feeds.last.complete(_page([original]));
      await feed;
      expect(h.cubit.state.posts.single.hasVisibleAuthor, isFalse);
      expect(h.cubit.state.posts.single.authorId, isNull);
    },
  );

  test(
    'a newer authorized reveal projection survives concurrent engagement',
    () async {
      final h = _Harness();
      final visible = _post('a').copyWith(anonymous: true);
      final masked = visible.copyWith(
        canViewAuthor: false,
        authorId: null,
        authorUsername: 'Anonymous',
      );
      await h.seed([masked]);
      final detail = h.cubit.refreshPost('a');
      h.cubit.incrementCommentCount('a');
      h.repository.details.single.complete(Result.success(visible));
      await detail;
      final current = h.cubit.state.posts.single;
      expect(current.hasVisibleAuthor, isTrue);
      expect(current.authorId, visible.authorId);
      expect(current.commentCount, 1);
    },
  );

  test(
    'a fresh ghost projection replaces the old avatar during a like',
    () async {
      final h = _Harness();
      final original = _post('a').copyWith(authorAvatarUrl: 'old-avatar');
      await h.seed([original]);
      final feed = h.cubit.load();
      final liking = h.cubit.toggleLike(original);
      final ghost = OverthinkingPostModel.fromJson({
        'id': 'a',
        'authorId': 'author',
        'authorUsername': 'ghost_username',
        'authorVisibilityMode': 'GHOST',
        'canViewAuthor': true,
        'title': 'a',
        'content': 'Content',
      });
      h.repository.feeds.last.complete(_page([ghost]));
      await feed;
      final current = h.cubit.state.posts.single;
      expect(current.isVisibleGhostAuthor, isTrue);
      expect(current.authorUsername, 'ghost_username');
      expect(current.authorAvatarUrl, isNull);
      expect(current.likedByMe, isTrue);
      h.engagement.calls.single.result.complete(const Result.success(null));
      await liking;
    },
  );

  test(
    'an update response keeps likes confirmed while it was pending',
    () async {
      final h = _Harness();
      final original = _post('a');
      await h.seed([original]);
      final update = h.update(original);
      final liking = h.cubit.toggleLike(original);
      h.engagement.calls.single.result.complete(const Result.success(null));
      await liking;
      h.repository.updates.single.complete(
        Result.success(original.copyWith(title: 'edited')),
      );
      await update;
      expect(h.cubit.state.posts.single.title, 'edited');
      expect(h.cubit.state.posts.single.likedByMe, isTrue);
      expect(h.cubit.state.posts.single.likeCount, 1);
    },
  );

  test('duplicate reveal requests are suppressed while pending', () async {
    final h = _Harness();
    final original = _post('a');
    final reveal = h.cubit.requestReveal(original);
    expect(await h.cubit.requestReveal(original), isFalse);
    expect(h.repository.reveals, hasLength(1));
    h.repository.reveals.single.complete(const Result.success(null));
    expect(await reveal, isTrue);
    expect(h.cubit.state.revealRequestingIds, isEmpty);
  });

  for (final action in [
    'load',
    'more',
    'detail',
    'create',
    'update',
    'delete',
    'like',
    'reveal',
  ]) {
    test('closing during $action ignores its late completion', () async {
      final h = _Harness();
      final post = _post('a');
      await h.seed([post], hasNext: true);
      final Future<Object?> operation;
      final void Function() complete;
      switch (action) {
        case 'load':
          operation = h.cubit.load();
          complete = () => h.repository.feeds.last.complete(_page([post]));
        case 'more':
          operation = h.cubit.loadMore();
          complete = () => h.repository.feeds.last.complete(_page([post]));
        case 'detail':
          operation = h.cubit.refreshPost('a');
          complete = () =>
              h.repository.details.single.complete(Result.success(post));
        case 'create':
          operation = h.create();
          complete = () =>
              h.repository.creates.single.complete(Result.success(post));
        case 'update':
          operation = h.update(post);
          complete = () =>
              h.repository.updates.single.complete(Result.success(post));
        case 'delete':
          operation = h.cubit.deletePost('a');
          complete = () =>
              h.repository.deletes.single.complete(const Result.success(null));
        case 'like':
          operation = h.cubit.toggleLike(post);
          complete = () => h.engagement.calls.single.result.complete(
            const Result.failure(_offline),
          );
        case 'reveal':
          operation = h.cubit.requestReveal(post);
          complete = () =>
              h.repository.reveals.single.complete(const Result.success(null));
        default:
          throw StateError(action);
      }
      await h.cubit.close();
      final closedState = h.cubit.state;
      complete();
      await expectLater(operation, completes);
      expect(h.cubit.state, same(closedState));
      await h.cubit.load();
      h.cubit.incrementCommentCount('a');
      expect(h.cubit.state, same(closedState));
    });
  }
}

OverthinkingPost _post(String id) => OverthinkingPostModel.fromJson({
  'id': id,
  'authorId': 'author',
  'authorUsername': 'Author',
  'canViewAuthor': true,
  'visibilityType': 'VISIBLE',
  'title': id,
  'content': 'Content',
});

Result<Page<OverthinkingPost>> _page(
  List<OverthinkingPost> posts, {
  bool hasNext = false,
}) => Result.success(Page(items: posts, hasNext: hasNext));

class _Harness {
  final repository = _Repository();
  final engagement = _Engagement();
  late final cubit = OverthinkingFeedCubit(
    overthinkingRepository: repository,
    engagementRepository: engagement,
  );

  _Harness() {
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
  }

  List<String> get ids => cubit.state.posts.map((post) => post.id).toList();

  Future<void> seed(
    List<OverthinkingPost> posts, {
    bool hasNext = false,
  }) async {
    final operation = cubit.load();
    repository.feeds.last.complete(_page(posts, hasNext: hasNext));
    await operation;
  }

  Future<bool> create() =>
      cubit.createPost(title: 'new', content: 'body', anonymous: false);
  Future<bool> update(OverthinkingPost post) => cubit.updatePost(
    post: post,
    title: 'edited',
    content: 'edited body',
    anonymous: false,
  );
}

class _Repository implements OverthinkingRepository {
  final feeds = <Completer<Result<Page<OverthinkingPost>>>>[];
  final details = <Completer<Result<OverthinkingPost>>>[];
  final creates = <Completer<Result<OverthinkingPost>>>[];
  final updates = <Completer<Result<OverthinkingPost>>>[];
  final deletes = <Completer<Result<void>>>[];
  final reveals = <Completer<Result<void>>>[];

  Future<Result<T>> _pending<T>(List<Completer<Result<T>>> requests) {
    final request = Completer<Result<T>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #getFeed => _pending(feeds),
        #getDetail => _pending(details),
        #createPost => _pending(creates),
        #updatePost => _pending(updates),
        #deletePost => _pending(deletes),
        #requestReveal => _pending(reveals),
        _ => super.noSuchMethod(invocation),
      };
}

class _LikeRequest {
  _LikeRequest(this.liked);
  final bool liked;
  final result = Completer<Result<void>>();
}

class _Engagement implements EngagementRepository {
  final calls = <_LikeRequest>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #like || invocation.memberName == #unlike) {
      final request = _LikeRequest(invocation.memberName == #like);
      calls.add(request);
      return request.result.future;
    }
    return super.noSuchMethod(invocation);
  }
}
