import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_feed_sort.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_state.dart';

import 'support/event_audience_fakes.dart';

const _offline = AppError(code: 'NETWORK', message: 'Offline');

void main() {
  group('global feed sorting', () {
    test(
      'changing sort resets paging and ignores an older load-more response',
      () async {
        final h = _Harness();
        await h.seed([_post('newest')], hasNext: true);
        final more = h.cubit.loadMore();
        final oldPage = h.repository.feeds.last;
        final sorting = h.cubit.setSort(OverthinkingFeedSort.oldest);
        expect(h.cubit.state.posts, isEmpty);
        expect(h.cubit.state.page, 0);
        expect(h.cubit.state.hasNext, isFalse);
        expect(h.repository.feeds.last.sort, OverthinkingFeedSort.oldest);
        expect(h.repository.feeds.last.page, 0);
        h.repository.feeds.last.complete([_post('oldest')], hasNext: true);
        await sorting;
        oldPage.complete([_post('stale-page')]);
        await more;
        expect(h.ids, ['oldest']);
        expect(h.cubit.state.page, 0);
        final next = h.cubit.loadMore();
        expect(h.repository.feeds.last.sort, OverthinkingFeedSort.oldest);
        expect(h.repository.feeds.last.page, 1);
        h.repository.feeds.last.complete([_post('next-oldest')]);
        await next;
        expect(h.ids, ['oldest', 'next-oldest']);
      },
    );

    test(
      'rapid sort changes ignore older failures and refresh retains selection',
      () async {
        final h = _Harness();
        final newest = h.cubit.load();
        final newestRead = h.repository.feeds.last;
        final liked = h.cubit.setSort(OverthinkingFeedSort.mostLiked);
        final likedRead = h.repository.feeds.last;
        final oldest = h.cubit.setSort(OverthinkingFeedSort.oldest);
        h.repository.feeds.last.complete([_post('oldest')]);
        await oldest;
        newestRead.result.complete(const Result.failure(_offline));
        likedRead.complete([_post('liked')]);
        await Future.wait([newest, liked]);
        expect(h.ids, ['oldest']);
        expect(h.cubit.state.error, isNull);
        expect(h.cubit.state.status, OverthinkingFeedStatus.idle);
        final refresh = h.cubit.load();
        expect(h.repository.feeds.last.sort, OverthinkingFeedSort.oldest);
        h.repository.feeds.last.complete([_post('fresh-oldest')]);
        await refresh;
        final count = h.repository.feeds.length;
        await h.cubit.setSort(OverthinkingFeedSort.oldest);
        expect(h.repository.feeds, hasLength(count));
      },
    );

    test(
      'detail started before a sort change cannot insert a post into the new page',
      () async {
        final h = _Harness();
        await h.seed([_post('new')]);
        final detail = h.cubit.refreshPost('new');
        final sort = h.cubit.setSort(OverthinkingFeedSort.oldest);
        h.repository.feeds.last.complete([_post('old')]);
        await sort;
        h.repository.details.single.complete(Result.success(_post('new')));
        await detail;
        expect(h.ids, ['old']);
      },
    );

    for (final sort in [
      OverthinkingFeedSort.oldest,
      OverthinkingFeedSort.mostLiked,
    ]) {
      test(
        'create under $sort obtains server order instead of prepending locally',
        () async {
          final h = _Harness();
          final sorting = h.cubit.setSort(sort);
          h.repository.feeds.last.complete([_post('ranked-first')]);
          await sorting;
          final create = h.cubit.createPost(
            title: 'New',
            content: 'Text',
            anonymous: true,
          );
          h.repository.creates.single.complete(Result.success(_post('new')));
          await _flush();
          expect(h.ids, ['ranked-first']);
          expect(h.repository.feeds.last.sort, sort);
          h.repository.feeds.last.complete([_post('ranked-first')]);
          expect(await create, isTrue);
          expect(h.ids, ['ranked-first']);
          expect(h.cubit.state.sort, sort);
        },
      );
    }
  });

  group('persistent reveal toggle', () {
    test(
      'notification detail publishes send success before its first read completes',
      () async {
        final h = _Harness();
        final post = _post('a');
        final detail = h.cubit.refreshPost(post.id);
        final send = h.cubit.toggleReveal(post);
        h.repository.sends.single.complete(const Result.success(null));
        expect(await send, isTrue);
        expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
        h.repository.details.single.complete(const Result.failure(_offline));
        await detail;
        expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
        final cancel = h.cubit.toggleReveal(post);
        expect(h.repository.cancels, hasLength(1));
        h.repository.cancels.single.complete(const Result.success(null));
        expect(await cancel, isTrue);
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
      },
    );

    test(
      'server pending survives reload and stale card taps cancel then resend',
      () async {
        final h = _Harness();
        final staleCard = _post('a', pending: true);
        await h.seed([staleCard]);
        final cancel = h.cubit.toggleReveal(staleCard);
        expect(h.repository.cancels, hasLength(1));
        expect(await h.cubit.toggleReveal(staleCard), isFalse);
        h.repository.cancels.single.complete(const Result.success(null));
        expect(await cancel, isTrue);
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
        final send = h.cubit.toggleReveal(staleCard);
        expect(h.repository.sends, hasLength(1));
        h.repository.sends.single.complete(const Result.success(null));
        expect(await send, isTrue);
        expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
        expect(await h.cubit.requestReveal(staleCard), isTrue);
        expect(h.repository.sends, hasLength(1));
        await h.seed([_post('a', pending: true)]);
        expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
      },
    );

    for (final pending in [false, true]) {
      for (final afterMutation in [false, true]) {
        test(
          '${pending ? 'cancel' : 'send'} protects a GET started ${afterMutation ? 'during' : 'before'} its mutation',
          () async {
            final h = _Harness();
            final original = _post('a', pending: pending);
            await h.seed([original]);
            Future<void>? reading;
            if (!afterMutation) reading = h.cubit.load();
            final write = h.cubit.toggleReveal(original);
            reading ??= h.cubit.load();
            final response = h.repository.feeds.last;
            (pending ? h.repository.cancels : h.repository.sends).single
                .complete(const Result.success(null));
            expect(await write, isTrue);
            response.complete([original]);
            await reading;
            expect(h.cubit.state.posts.single.revealRequestPending, !pending);
            // A later authoritative read can reflect a decision or another device.
            await h.seed([original]);
            expect(h.cubit.state.posts.single.revealRequestPending, pending);
          },
        );
      }
    }

    test('read completing during send remains stable until success', () async {
      final h = _Harness();
      final post = _post('a');
      await h.seed([post]);
      final send = h.cubit.toggleReveal(post);
      await h.seed([post.copyWith(revealRequestPending: true)]);
      expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
      expect(h.cubit.state.revealRequestingIds, {'a'});
      h.repository.sends.single.complete(const Result.success(null));
      await send;
      expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
    });

    test(
      'failed cancellation retains pending status and releases duplicate guard',
      () async {
        final h = _Harness();
        final post = _post('a', pending: true);
        await h.seed([post]);
        final cancel = h.cubit.toggleReveal(post);
        h.repository.cancels.single.complete(const Result.failure(_offline));
        expect(await cancel, isFalse);
        expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
        expect(h.cubit.state.revealRequestingIds, isEmpty);
        expect(h.cubit.state.error, same(_offline));
      },
    );

    test(
      'author decision racing cancel refreshes identity and preserves conflict feedback',
      () async {
        final h = _Harness();
        final post = _post('a', pending: true);
        await h.seed([post]);
        final cancel = h.cubit.toggleReveal(post);
        const conflict = AppError(code: '9409', message: 'Already decided');
        h.repository.cancels.single.complete(const Result.failure(conflict));
        await _flush();
        expect(h.cubit.state.revealRequestingIds, {'a'});
        expect(await h.cubit.toggleReveal(post), isFalse);
        h.repository.details.single.complete(
          Result.success(
            post.copyWith(
              revealRequestPending: false,
              canViewAuthor: true,
              authorId: 'author',
            ),
          ),
        );
        expect(await cancel, isFalse);
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
        expect(h.cubit.state.posts.single.canViewAuthor, isTrue);
        expect(h.cubit.state.error, same(conflict));
        expect(h.cubit.state.revealRequestingIds, isEmpty);
      },
    );

    test(
      'conflict detail settles pending across a sort change without inserting its old card',
      () async {
        final h = _Harness();
        final post = _post('a', pending: true);
        await h.seed([post]);
        final cancel = h.cubit.toggleReveal(post);
        h.repository.cancels.single.complete(
          const Result.failure(
            AppError(code: '9409', message: 'Already decided'),
          ),
        );
        await _flush();
        final sort = h.cubit.setSort(OverthinkingFeedSort.oldest);
        h.repository.feeds.last.complete([_post('different')], hasNext: true);
        await sort;
        h.repository.details.single.complete(
          Result.success(post.copyWith(revealRequestPending: false)),
        );
        expect(await cancel, isFalse);
        expect(h.ids, ['different']);
        final more = h.cubit.loadMore();
        h.repository.feeds.last.complete([
          post.copyWith(revealRequestPending: false),
        ]);
        await more;
        expect(h.cubit.state.posts.last.revealRequestPending, isFalse);
      },
    );

    test(
      'conflict reconciliation accepts the newer sorted page pending value',
      () async {
        final h = _Harness();
        final post = _post('a', pending: true);
        await h.seed([post]);
        final cancel = h.cubit.toggleReveal(post);
        h.repository.cancels.single.complete(
          const Result.failure(
            AppError(code: '9409', message: 'Already decided'),
          ),
        );
        await _flush();
        final sort = h.cubit.setSort(OverthinkingFeedSort.oldest);
        h.repository.feeds.last.complete([
          post.copyWith(revealRequestPending: false),
        ]);
        await sort;
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
        h.repository.details.single.complete(
          Result.success(post.copyWith(revealRequestPending: false)),
        );
        expect(await cancel, isFalse);
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
      },
    );

    test(
      'newer detail superseding conflict reconciliation can clear pending while the action stays locked',
      () async {
        final h = _Harness();
        final post = _post('a', pending: true);
        await h.seed([post]);
        final cancel = h.cubit.toggleReveal(post);
        h.repository.cancels.single.complete(
          const Result.failure(
            AppError(code: '9409', message: 'Already decided'),
          ),
        );
        await _flush();
        final newerDetail = h.cubit.refreshPost(post.id);
        h.repository.details.last.complete(
          Result.success(post.copyWith(revealRequestPending: false)),
        );
        await newerDetail;
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
        expect(h.cubit.state.revealRequestingIds, {'a'});
        h.repository.details.first.complete(Result.success(post));
        expect(await cancel, isFalse);
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
      },
    );

    test(
      'a local like cannot retain pending status masked by a newer detail',
      () async {
        final h = _Harness();
        final post = _post('a', pending: true);
        await h.seed([post]);
        final oldFeed = h.cubit.load();
        final feedResponse = h.repository.feeds.last;
        final detail = h.cubit.refreshPost('a');
        final like = h.cubit.toggleLike(post);
        h.repository.details.single.complete(
          Result.success(post.copyWith(revealRequestPending: false)),
        );
        await detail;
        feedResponse.complete([post]);
        await oldFeed;
        expect(h.cubit.state.posts.single.revealRequestPending, isFalse);
        expect(h.cubit.state.posts.single.likedByMe, isTrue);
        h.engagement.likes.single.complete(const Result.success(null));
        await like;
      },
    );

    test(
      'sort change during send preserves its result without inserting old-page content',
      () async {
        final h = _Harness();
        final post = _post('a');
        await h.seed([post]);
        final send = h.cubit.toggleReveal(post);
        final sorting = h.cubit.setSort(OverthinkingFeedSort.oldest);
        h.repository.sends.single.complete(const Result.success(null));
        await send;
        expect(h.ids, isEmpty);
        h.repository.feeds.last.complete([post]);
        await sorting;
        expect(h.cubit.state.posts.single.revealRequestPending, isTrue);
      },
    );

    for (final pending in [false, true]) {
      test(
        '${pending ? 'cancel' : 'send'} cannot update a replaced same-user session',
        () async {
          final sessions = AudienceTestSessions(
            audienceSession(user: 'viewer', token: 'old'),
          );
          final h = _Harness(sessions: sessions);
          addTearDown(sessions.dispose);
          final post = _post('a', pending: pending);
          await h.seed([post]);
          final operation = h.cubit.toggleReveal(post);
          sessions.replace(audienceSession(user: 'viewer', token: 'new'));
          (pending ? h.repository.cancels : h.repository.sends).single.complete(
            const Result.success(null),
          );
          expect(await operation, isFalse);
          expect(h.cubit.state.posts, isEmpty);
          expect(h.cubit.state.revealRequestingIds, isEmpty);
          expect(await h.cubit.toggleReveal(post), isFalse);
        },
      );
    }

    test('guest cannot dispatch either reveal action', () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      final h = _Harness(sessions: sessions);
      addTearDown(sessions.dispose);
      expect(await h.cubit.toggleReveal(_post('a')), isFalse);
      expect(await h.cubit.toggleReveal(_post('b', pending: true)), isFalse);
      expect(h.repository.sends, isEmpty);
      expect(h.repository.cancels, isEmpty);
    });
  });

  for (final cancel in [false, true]) {
    test(
      'real Dio ${cancel ? 'cancel' : 'send'} never adopts a replacement token after token await',
      () async {
        final oldToken = _jwt('old');
        final newToken = _jwt('new');
        final sessions = AudienceTestSessions(
          audienceSession(user: 'viewer', token: oldToken),
        );
        final tokens = _BlockedTokens();
        final adapter = _Adapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
          ..httpClientAdapter = adapter;
        addTearDown(() {
          dio.close(force: true);
          sessions.dispose();
        });
        final repository = OverthinkingRepositoryImpl(
          DioApiClient(dio: dio, tokenStore: tokens, sessionManager: sessions),
          sessions: sessions,
        );
        final operation = cancel
            ? repository.cancelReveal(postId: 'a')
            : repository.requestReveal(postId: 'a');
        await tokens.started.future;
        sessions.replace(audienceSession(user: 'viewer', token: newToken));
        tokens.release.complete(newToken);
        expect((await operation).error?.code, 'overthinking_session_changed');
        expect(adapter.requests, isEmpty);
      },
    );
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

OverthinkingPost _post(String id, {bool pending = false}) =>
    OverthinkingPostModel.fromJson({
      'id': id,
      'title': id,
      'anonymous': true,
      'canViewAuthor': false,
      'visibilityType': 'ANONYMOUS',
      'revealRequestPending': pending,
    });

class _FeedRead {
  _FeedRead(this.page, this.sort);
  final int page;
  final OverthinkingFeedSort sort;
  final result = Completer<Result<Page<OverthinkingPost>>>();
  void complete(List<OverthinkingPost> posts, {bool hasNext = false}) =>
      result.complete(Result.success(Page(items: posts, hasNext: hasNext)));
}

class _Repository extends Fake implements OverthinkingRepository {
  final feeds = <_FeedRead>[];
  final details = <Completer<Result<OverthinkingPost>>>[];
  final creates = <Completer<Result<OverthinkingPost>>>[];
  final sends = <Completer<Result<void>>>[];
  final cancels = <Completer<Result<void>>>[];

  Future<Result<T>> _pending<T>(List<Completer<Result<T>>> requests) {
    final request = Completer<Result<T>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
    OverthinkingFeedSort sort = OverthinkingFeedSort.newest,
  }) {
    final request = _FeedRead(page, sort);
    feeds.add(request);
    return request.result.future;
  }

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) =>
      _pending(details);
  @override
  Future<Result<void>> requestReveal({required String postId}) =>
      _pending(sends);
  @override
  Future<Result<void>> cancelReveal({required String postId}) =>
      _pending(cancels);
  @override
  Future<Result<OverthinkingPost>> createPost({
    String? clientRequestId,
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) => _pending(creates);
}

class _Engagement extends Fake implements EngagementRepository {
  final likes = <Completer<Result<void>>>[];
  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) {
    final result = Completer<Result<void>>();
    likes.add(result);
    return result.future;
  }
}

class _Harness {
  _Harness({AudienceTestSessions? sessions}) {
    cubit = OverthinkingFeedCubit(
      overthinkingRepository: repository,
      engagementRepository: engagement,
      sessions: sessions,
    );
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
  }
  final repository = _Repository();
  final engagement = _Engagement();
  late final OverthinkingFeedCubit cubit;
  List<String> get ids => cubit.state.posts.map((post) => post.id).toList();
  Future<void> seed(
    List<OverthinkingPost> posts, {
    bool hasNext = false,
  }) async {
    final loading = cubit.load();
    repository.feeds.last.complete(posts, hasNext: hasNext);
    await loading;
  }
}

String _jwt(String nonce) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': 'viewer', 'jti': nonce, 'exp': 4102444800})}.signature';
}

class _BlockedTokens extends Fake implements TokenStore {
  final started = Completer<void>();
  final release = Completer<String?>();
  @override
  Future<String?> readToken() {
    if (!started.isCompleted) started.complete();
    return release.future;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'code': 200, 'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
