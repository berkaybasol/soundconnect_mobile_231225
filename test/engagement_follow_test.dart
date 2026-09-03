import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/models/comment_item_model.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_state.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/data/follow_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/data/follow_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_state.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_count_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';

import 'support/recording_api_client.dart';

void main() {
  group('engagement JSON and repository boundaries', () {
    test('comment model coerces scalar fields and honors avatar aliases', () {
      final item = CommentItemModel.fromJson(<String, dynamic>{
        'id': 42,
        'user': <String, dynamic>{
          'id': 7,
          'username': 'ada',
          'profileImageUrl': 'https://cdn/avatar.jpg',
          'visibilityMode': 'GHOST',
        },
        'anonymousAuthor': true,
        'text': 99,
        'deleted': true,
        'parentCommentId': 12,
        'replyCount': 3.9,
        'createdAt': '2026-07-13T08:30:00Z',
      });

      expect(item.id, '42');
      expect(item.user.id, '7');
      expect(item.user.avatarUrl, 'https://cdn/avatar.jpg');
      expect(item.text, '99');
      expect(item.parentCommentId, '12');
      expect(item.replyCount, 3);
      expect(item.anonymousAuthor, isTrue);
      expect(item.deleted, isTrue);
      expect(item.createdAt?.toUtc(), DateTime.utc(2026, 7, 13, 8, 30));
      expect(item.user.visibilityMode, ListenerVisibilityMode.ghost);
      expect(item.user.isGhost, isTrue);
      expect(item.isVisibleGhostAuthor, isFalse);

      final masked = CommentItemModel.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': '',
          'username': 'Anonymous Author',
          'visibilityMode': 'GHOST',
        },
        'anonymousAuthor': true,
      });
      expect(masked.user.isGhost, isFalse);
      expect(masked.isVisibleGhostAuthor, isFalse);
    });

    test(
      'listComments decodes valid rows and sends stable paging query',
      () async {
        final client = RecordingApiClient((request) {
          expect(
            request.path,
            EngagementEndpoints.listComments('EVENT', 'event-1'),
          );
          return <String, dynamic>{
            'content': <Object?>[
              <String, dynamic>{
                'id': 'comment-1',
                'text': 'Merhaba',
                'replyCount': 2,
              },
              'malformed-row',
            ],
            'totalElements': 9,
          };
        });
        final repository = EngagementRepositoryImpl(client);

        final result = await repository.listComments(
          targetType: 'EVENT',
          targetId: 'event-1',
          page: 2,
          size: 10,
        );

        expect(result.isSuccess, isTrue);
        expect(result.data?.items, hasLength(1));
        expect(result.data?.items.single.user.username, 'unknown');
        expect(result.data?.totalElements, 9);
        expect(client.lastRequest.query, <String, dynamic>{
          'page': 2,
          'size': 10,
          'sort': 'createdAt,desc',
        });
      },
    );

    test(
      'typed API errors are preserved and unknown failures are mapped',
      () async {
        const apiError = AppError(code: '429', message: 'Slow down');
        final typedRepository = EngagementRepositoryImpl(
          RecordingApiClient((_) => throw ApiException(apiError)),
        );
        final unknownRepository = EngagementRepositoryImpl(
          RecordingApiClient((_) => throw StateError('broken payload')),
        );

        final typed = await typedRepository.getLikeCount(
          targetType: 'EVENT',
          targetId: '1',
        );
        final unknown = await unknownRepository.isLiked(
          targetType: 'EVENT',
          targetId: '1',
        );

        expect(typed.error, same(apiError));
        expect(unknown.error?.code, 'engagement_is_liked_unknown');
      },
    );
  });

  group('InteractionStatsCubit', () {
    test(
      'loads once, caches the item, and rolls back a failed optimistic like',
      () async {
        const failure = AppError(code: 'like_failed', message: 'Like failed');
        final repository = _EngagementRepositoryFake(
          likeCountResult: const Result.success(4),
          commentPageResult: const Result.success(
            CommentPage(items: <CommentItem>[], totalElements: 2),
          ),
          isLikedResult: const Result.success(false),
        );
        final cubit = InteractionStatsCubit(repository);

        await cubit.load(targetType: 'EVENT', targetId: 'event-1');
        await cubit.load(targetType: 'EVENT', targetId: 'event-1');

        final loaded = cubit.state.items['EVENT:event-1']!;
        expect(loaded.likeCount, 4);
        expect(loaded.commentCount, 2);
        expect(loaded.isLiked, isFalse);
        expect(repository.likeCountCalls, 1);

        repository.likeResult = const Result.failure(failure);
        final expectation = expectLater(
          cubit.stream,
          emitsInOrder(<Matcher>[
            isA<InteractionStatsState>()
                .having(
                  (state) => state.items['EVENT:event-1']?.isLiked,
                  'optimistic liked state',
                  isTrue,
                )
                .having(
                  (state) => state.items['EVENT:event-1']?.likeCount,
                  'optimistic count',
                  5,
                ),
            isA<InteractionStatsState>()
                .having(
                  (state) => state.items['EVENT:event-1']?.isLiked,
                  'rolled-back liked state',
                  isFalse,
                )
                .having(
                  (state) => state.items['EVENT:event-1']?.likeCount,
                  'rolled-back count',
                  4,
                )
                .having(
                  (state) => state.items['EVENT:event-1']?.error,
                  'typed failure',
                  same(failure),
                ),
          ]),
        );
        await cubit.toggleLike(targetType: 'EVENT', targetId: 'event-1');
        await expectation;
        await cubit.close();
      },
    );
  });

  group('follow repository and cubits', () {
    test(
      'follow sends the canonical body and numeric counts are coerced',
      () async {
        final client = RecordingApiClient((request) {
          if (request.path == FollowEndpoints.follow) {
            return null;
          }
          return 8.9;
        });
        final repository = FollowRepositoryImpl(client);

        final action = await repository.follow(
          followerId: 'user-1',
          followingId: 'user-2',
        );
        final count = await repository.getFollowersCount('user-2');

        expect(action.isSuccess, isTrue);
        expect(client.requests.first.method, RecordedHttpMethod.post);
        expect(client.requests.first.body, <String, dynamic>{
          'followerId': 'user-1',
          'followingId': 'user-2',
        });
        expect(count.data, 8);
        expect(
          client.lastRequest.path,
          FollowEndpoints.countFollowers('user-2'),
        );
      },
    );

    test('FollowActionCubit keeps status after a failed toggle', () async {
      const failure = AppError(code: 'unfollow_failed', message: 'Try again');
      final repository = _FollowRepositoryFake(
        statusResult: const Result.success(true),
        followResult: const Result.success(null),
        unfollowResult: const Result.failure(failure),
      );
      final cubit = FollowActionCubit(repository);

      await cubit.loadStatus(followerId: 'a', followingId: 'b');
      expect(cubit.state.isFollowing, isTrue);
      await cubit.toggleFollow(followerId: 'a', followingId: 'b');

      expect(cubit.state.status, FollowActionStatus.failure);
      expect(cubit.state.isFollowing, isTrue);
      expect(cubit.state.error, same(failure));
      expect(repository.unfollowCalls, 1);
      await cubit.close();
    });

    test(
      'FollowCountCubit retains successful half of a partial failure',
      () async {
        const failure = AppError(
          code: 'following_failed',
          message: 'Unavailable',
        );
        final repository = _FollowRepositoryFake(
          followersResult: const Result.success(12),
          followingResult: const Result.failure(failure),
        );
        final cubit = FollowCountCubit(repository);

        await cubit.loadCounts('user-1');

        expect(cubit.state.status, FollowCountStatus.failure);
        expect(cubit.state.followersCount, 12);
        expect(cubit.state.followingCount, 0);
        expect(cubit.state.error, same(failure));
        await cubit.close();
      },
    );
  });
}

class _EngagementRepositoryFake implements EngagementRepository {
  _EngagementRepositoryFake({
    this.likeCountResult = const Result.success(0),
    this.commentPageResult = const Result.success(
      CommentPage(items: <CommentItem>[], totalElements: 0),
    ),
    this.isLikedResult = const Result.success(false),
  });

  Result<int> likeCountResult;
  Result<CommentPage> commentPageResult;
  Result<bool> isLikedResult;
  Result<void> likeResult = const Result.success(null);
  Result<void> unlikeResult = const Result.success(null);
  int likeCountCalls = 0;

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async {
    likeCountCalls += 1;
    return likeCountResult;
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async => isLikedResult;

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async => likeResult;

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async => unlikeResult;

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => commentPageResult;

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async => Result.success(_comment('created'));

  @override
  Future<Result<void>> deleteComment({required String commentId}) async =>
      const Result.success(null);

  @override
  Future<Result<List<CommentItem>>> listReplies(String commentId) async =>
      const Result.success(<CommentItem>[]);
}

class _FollowRepositoryFake implements FollowRepository {
  _FollowRepositoryFake({
    this.followersResult = const Result.success(0),
    this.followingResult = const Result.success(0),
    this.statusResult = const Result.success(false),
    this.followResult = const Result.success(null),
    this.unfollowResult = const Result.success(null),
  });

  Result<int> followersResult;
  Result<int> followingResult;
  Result<bool> statusResult;
  Result<void> followResult;
  Result<void> unfollowResult;
  int unfollowCalls = 0;

  @override
  Future<Result<int>> getFollowersCount(String userId) async => followersResult;

  @override
  Future<Result<int>> getFollowingCount(String userId) async => followingResult;

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) async => followResult;

  @override
  Future<Result<void>> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    unfollowCalls += 1;
    return unfollowResult;
  }

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async => statusResult;
}

CommentItem _comment(String id) {
  return CommentItem(
    id: id,
    user: const CommentUserSummary(
      id: 'user-1',
      username: 'ada',
      avatarUrl: null,
    ),
    text: 'text',
    deleted: false,
    parentCommentId: null,
    replyCount: 0,
    createdAt: null,
  );
}
