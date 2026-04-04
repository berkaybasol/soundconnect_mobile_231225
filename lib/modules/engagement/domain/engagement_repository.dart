import '../../../core/error/result.dart';
import 'entities/comment_item.dart';
import 'entities/comment_page.dart';

abstract class EngagementRepository {
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  });

  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  });

  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  });

  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  });

  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  });

  Future<Result<List<CommentItem>>> listReplies(String commentId);

  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  });

  Future<Result<void>> deleteComment({
    required String commentId,
  });
}
