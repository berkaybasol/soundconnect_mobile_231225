import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_reveal_request_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_state.dart';

void main() {
  group('overthinking models', () {
    test('post model normalizes nullable text and numeric counters', () {
      final model = OverthinkingPostModel.fromJson(<String, dynamic>{
        'id': 7,
        'authorAvatarUrl': '  ',
        'anonymous': true,
        'canViewAuthor': 'true',
        'title': 'Title',
        'spotifyTrackUrl': ' https://track ',
        'likeCount': 4.9,
        'commentCount': 2,
        'likedByMe': true,
      });

      expect(model.id, '7');
      expect(model.authorUsername, isNotEmpty);
      expect(model.authorAvatarUrl, isNull);
      expect(model.anonymous, isTrue);
      expect(model.canViewAuthor, isFalse);
      expect(model.visibilityType, 'VISIBLE');
      expect(model.spotifyTrackUrl, 'https://track');
      expect(model.likeCount, 4);
      expect(model.commentCount, 2);
      expect(model.likedByMe, isTrue);
    });

    test('reveal request parses valid dates and defaults invalid values', () {
      final parsed = OverthinkingRevealRequestModel.fromJson(<String, dynamic>{
        'id': 'r-1',
        'postId': 3,
        'createdAt': '2026-07-13T12:00:00Z',
      });
      final invalid = OverthinkingRevealRequestModel.fromJson(<String, dynamic>{
        'createdAt': 'bad-date',
      });

      expect(parsed.postId, '3');
      expect(parsed.status, 'PENDING');
      expect(parsed.createdAt, DateTime.utc(2026, 7, 13, 12));
      expect(invalid.createdAt, isNull);
    });
  });

  group('OverthinkingRepositoryImpl', () {
    test('uses canonical feed path/query and decodes pagination', () async {
      final apiClient = _OverthinkingApiClientFake((method, path, query, body) {
        return <String, dynamic>{
          'number': 2,
          'last': false,
          'content': <Object?>[
            <String, dynamic>{'id': 'p-1', 'title': 'Post'},
          ],
        };
      });
      final repository = OverthinkingRepositoryImpl(apiClient);

      final result = await repository.getFeed(page: 2, size: 7);

      expect(result.data?.items.single.id, 'p-1');
      expect(result.data?.nextCursor, '3');
      expect(apiClient.lastMethod, 'GET');
      expect(apiClient.lastPath, OverthinkingEndpoints.feed);
      expect(apiClient.lastQuery, <String, dynamic>{
        'page': 2,
        'size': 7,
        'sort': 'createdAt,desc',
      });
    });

    test('sends canonical create path and complete request body', () async {
      final apiClient = _OverthinkingApiClientFake((method, path, query, body) {
        return <String, dynamic>{'id': 'created', 'title': 'Title'};
      });
      final repository = OverthinkingRepositoryImpl(apiClient);

      final result = await repository.createPost(
        title: 'Title',
        content: 'Content',
        visibilityType: 'ANONYMOUS',
        spotifyTrackUrl: 'track-url',
      );

      expect(result.data?.id, 'created');
      expect(apiClient.lastMethod, 'POST');
      expect(apiClient.lastPath, OverthinkingEndpoints.create);
      expect(apiClient.lastBody, <String, dynamic>{
        'title': 'Title',
        'content': 'Content',
        'visibilityType': 'ANONYMOUS',
        'spotifyTrackUrl': 'track-url',
        'spotifyArtistId': null,
        'spotifyTrackName': null,
        'spotifyArtistName': null,
        'spotifyAlbumImageUrl': null,
        'musicianTrackId': null,
        'bandTrackId': null,
      });
    });

    test('preserves typed errors and maps unexpected payload errors', () async {
      const error = AppError(code: '403', message: 'Forbidden');
      final typedRepository = OverthinkingRepositoryImpl(
        _OverthinkingApiClientFake(
          (_, __, ___, ____) => throw ApiException(error),
        ),
      );
      final unknownRepository = OverthinkingRepositoryImpl(
        _OverthinkingApiClientFake((_, __, ___, ____) => 'invalid-page'),
      );

      final typedResult = await typedRepository.getDetail(postId: 'p-1');
      final unknownResult = await unknownRepository.getFeed();

      expect(typedResult.error, same(error));
      expect(unknownResult.error?.code, 'overthinking_feed_unknown');
    });
  });

  group('OverthinkingFeedCubit', () {
    test('loads and appends pages while advancing pagination state', () async {
      final repository = _OverthinkingRepositoryFake(
        pages: <int, Result<Page<OverthinkingPost>>>{
          0: Result.success(
            Page<OverthinkingPost>(
              items: <OverthinkingPost>[_post('p-1')],
              hasNext: true,
            ),
          ),
          1: Result.success(
            Page<OverthinkingPost>(
              items: <OverthinkingPost>[_post('p-2')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = OverthinkingFeedCubit(
        overthinkingRepository: repository,
        engagementRepository: _EngagementRepositoryFake(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.status, OverthinkingFeedStatus.idle);
      expect(cubit.state.posts.map((item) => item.id), <String>['p-1', 'p-2']);
      expect(cubit.state.page, 1);
      expect(cubit.state.hasNext, isFalse);
      expect(repository.requestedPages, <int>[0, 1]);
    });

    test('rolls back optimistic like when engagement call fails', () async {
      const error = AppError(code: 'offline', message: 'Offline');
      final original = _post('p-1', likeCount: 0);
      final repository = _OverthinkingRepositoryFake(
        pages: <int, Result<Page<OverthinkingPost>>>{
          0: Result.success(
            Page<OverthinkingPost>(
              items: <OverthinkingPost>[original],
              hasNext: false,
            ),
          ),
        },
      );
      final likeCompleter = Completer<Result<void>>();
      final engagement = _EngagementRepositoryFake(
        likeFuture: likeCompleter.future,
      );
      final cubit = OverthinkingFeedCubit(
        overthinkingRepository: repository,
        engagementRepository: engagement,
      );
      addTearDown(cubit.close);
      await cubit.load();

      final operation = cubit.toggleLike(original);

      expect(cubit.state.posts.single.likedByMe, isTrue);
      expect(cubit.state.posts.single.likeCount, 1);
      expect(cubit.state.error, isNull);

      likeCompleter.complete(const Result.failure(error));
      await operation;

      expect(cubit.state.posts.single.likedByMe, isFalse);
      expect(cubit.state.posts.single.likeCount, 0);
      expect(cubit.state.error, same(error));
      expect(engagement.lastTargetType, OverthinkingFeedCubit.targetType);
      expect(engagement.lastTargetId, 'p-1');
    });

    test(
      'creates anonymous post with visibility mapping and prepends it',
      () async {
        final created = _post('created', anonymous: true);
        final repository = _OverthinkingRepositoryFake(
          pages: <int, Result<Page<OverthinkingPost>>>{
            0: Result.success(
              Page<OverthinkingPost>(
                items: <OverthinkingPost>[_post('existing')],
                hasNext: false,
              ),
            ),
          },
          createResult: Result.success(created),
        );
        final cubit = OverthinkingFeedCubit(
          overthinkingRepository: repository,
          engagementRepository: _EngagementRepositoryFake(),
        );
        addTearDown(cubit.close);
        await cubit.load();

        final createdSuccessfully = await cubit.createPost(
          title: 'Title',
          content: 'Content',
          anonymous: true,
          spotifyTrackUrl: 'track',
        );

        expect(createdSuccessfully, isTrue);
        expect(cubit.state.posts.map((item) => item.id), <String>[
          'created',
          'existing',
        ]);
        expect(cubit.state.submitting, isFalse);
        expect(repository.lastVisibilityType, 'ANONYMOUS');
        expect(repository.lastSpotifyTrackUrl, 'track');
      },
    );

    test('clears reveal in-flight marker and exposes request error', () async {
      const error = AppError(code: 'duplicate', message: 'Already requested');
      final post = _post('p-1');
      final repository = _OverthinkingRepositoryFake(
        revealResult: const Result.failure(error),
      );
      final cubit = OverthinkingFeedCubit(
        overthinkingRepository: repository,
        engagementRepository: _EngagementRepositoryFake(),
      );
      addTearDown(cubit.close);

      final requested = await cubit.requestReveal(post);

      expect(requested, isFalse);
      expect(cubit.state.revealRequestingIds, isEmpty);
      expect(cubit.state.error, same(error));
      expect(repository.lastRevealPostId, 'p-1');
    });

    test('increments only the matching post comment count', () async {
      final repository = _OverthinkingRepositoryFake(
        pages: <int, Result<Page<OverthinkingPost>>>{
          0: Result.success(
            Page<OverthinkingPost>(
              items: <OverthinkingPost>[
                _post('p-1', commentCount: 3),
                _post('p-2', commentCount: 8),
              ],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = OverthinkingFeedCubit(
        overthinkingRepository: repository,
        engagementRepository: _EngagementRepositoryFake(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      cubit.incrementCommentCount('p-1');
      cubit.incrementCommentCount('missing');

      expect(cubit.state.posts[0].commentCount, 4);
      expect(cubit.state.posts[1].commentCount, 8);
    });
  });
}

OverthinkingPost _post(
  String id, {
  bool anonymous = false,
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
}) {
  return OverthinkingPost(
    id: id,
    authorId: 'author-1',
    authorUsername: 'Author',
    authorAvatarUrl: null,
    anonymous: anonymous,
    canViewAuthor: true,
    visibilityType: anonymous ? 'ANONYMOUS' : 'VISIBLE',
    title: id,
    content: 'Content',
    spotifyTrackUrl: null,
    spotifyArtistId: null,
    spotifyTrackName: null,
    spotifyArtistName: null,
    spotifyAlbumImageUrl: null,
    musicianTrackId: null,
    bandTrackId: null,
    artistId: null,
    artistType: null,
    likeCount: likeCount,
    commentCount: commentCount,
    likedByMe: likedByMe,
  );
}

class _OverthinkingRepositoryFake implements OverthinkingRepository {
  _OverthinkingRepositoryFake({
    this.pages = const <int, Result<Page<OverthinkingPost>>>{},
    Result<OverthinkingPost>? createResult,
    this.revealResult = const Result.success(null),
  }) : createResult = createResult ?? Result.success(_post('created'));

  final Map<int, Result<Page<OverthinkingPost>>> pages;
  final Result<OverthinkingPost> createResult;
  final Result<void> revealResult;
  final List<int> requestedPages = <int>[];
  String? lastVisibilityType;
  String? lastSpotifyTrackUrl;
  String? lastRevealPostId;

  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return pages[page] ??
        const Result.success(
          Page<OverthinkingPost>(items: <OverthinkingPost>[], hasNext: false),
        );
  }

  @override
  Future<Result<OverthinkingPost>> createPost({
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    lastVisibilityType = visibilityType;
    lastSpotifyTrackUrl = spotifyTrackUrl;
    return createResult;
  }

  @override
  Future<Result<void>> requestReveal({required String postId}) async {
    lastRevealPostId = postId;
    return revealResult;
  }

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async =>
      Result.success(_post(postId));

  @override
  Future<Result<void>> deletePost({required String postId}) async =>
      const Result.success(null);

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async => getFeed(page: page, size: size);

  @override
  Future<Result<Page<OverthinkingPost>>> getPostsByArtist({
    required String artistId,
    int page = 0,
    int size = 20,
  }) async => getFeed(page: page, size: size);

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(
    Page<OverthinkingRevealRequest>(
      items: <OverthinkingRevealRequest>[],
      hasNext: false,
    ),
  );

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(
    Page<OverthinkingRevealRequest>(
      items: <OverthinkingRevealRequest>[],
      hasNext: false,
    ),
  );

  @override
  Future<Result<OverthinkingRevealRequest>> approveRevealRequest({
    required String requestId,
  }) => throw UnimplementedError();

  @override
  Future<Result<OverthinkingRevealRequest>> rejectRevealRequest({
    required String requestId,
  }) => throw UnimplementedError();

  @override
  Future<Result<OverthinkingPost>> updatePost({
    required String postId,
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
    String? musicianTrackId,
    String? bandTrackId,
  }) async => Result.success(_post(postId));
}

class _EngagementRepositoryFake implements EngagementRepository {
  _EngagementRepositoryFake({this.likeFuture});

  final Future<Result<void>>? likeFuture;
  String? lastTargetType;
  String? lastTargetId;

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    lastTargetType = targetType;
    lastTargetId = targetId;
    return await (likeFuture ??
        Future<Result<void>>.value(const Result.success(null)));
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    lastTargetType = targetType;
    lastTargetId = targetId;
    return await (likeFuture ??
        Future<Result<void>>.value(const Result.success(null)));
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteComment({required String commentId}) =>
      throw UnimplementedError();

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) => throw UnimplementedError();

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) => throw UnimplementedError();

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<CommentItem>>> listReplies(String commentId) =>
      throw UnimplementedError();
}

class _OverthinkingApiClientFake extends ApiClient {
  _OverthinkingApiClientFake(this.handler);

  final FutureOr<Object?> Function(
    String method,
    String path,
    Map<String, dynamic>? query,
    Object? body,
  )
  handler;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  Future<T> _execute<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastQuery = query;
    lastBody = body;
    final payload = await handler(method, path, query, body);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) => _execute('GET', path, query: query, decoder: decoder);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('POST', path, body: body, decoder: decoder);

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('PUT', path, body: body, decoder: decoder);

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('DELETE', path, body: body, decoder: decoder);

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('PATCH', path, body: body, decoder: decoder);
}
