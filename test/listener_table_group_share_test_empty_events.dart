part of 'listener_table_group_share_test.dart';

class _EmptyEvents extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  @override
  ValueNotifier<int> get changes => signal;
  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    EventAudiencePage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    ),
  );
}

class _EmptyThoughts extends Fake
    implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueNotifier<int> get changes => signal;
  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: const [], hasNext: false));
}

class _Engagement extends Fake implements EngagementRepository {
  final calls = <(String, String, String)>[];
  Future<Result<void>> Function()? onLike;
  bool liked = false;
  final created = <(String, String, String)>[];

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    created.add((targetType, targetId, text));
    return Result.success(
      CommentItem(
        id: 'comment-${created.length}',
        user: const CommentUserSummary(
          id: 'sharer',
          username: 'sharer',
          avatarUrl: null,
        ),
        text: text,
        deleted: false,
        parentCommentId: parentCommentId,
        replyCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('count', targetType, targetId));
    return Result.success(liked ? 4 : 3);
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('liked', targetType, targetId));
    return Result.success(liked);
  }

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('like', targetType, targetId));
    final result =
        await (onLike?.call() ??
            Future.value(const Result<void>.success(null)));
    if (result.isSuccess) liked = true;
    return result;
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('unlike', targetType, targetId));
    liked = false;
    return const Result.success(null);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    calls.add(('comments', targetType, targetId));
    return Result.success(
      CommentPage(items: const [], totalElements: 0, page: page, size: size),
    );
  }
}
