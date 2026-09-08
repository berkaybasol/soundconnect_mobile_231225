import '../../../core/error/result.dart';
import '../../../core/error/app_error.dart';
import 'entities/comment_item.dart';
import 'entities/comment_page.dart';
import 'entities/comment_like_state.dart';

abstract class EngagementRepository {
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) async => const Result.failure(
    AppError(
      code: 'comment_like_unavailable',
      message: 'Beğeni güncellenemedi.',
    ),
  );

  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) async => const Result.failure(
    AppError(
      code: 'comment_like_unavailable',
      message: 'Beğeni durumu alınamadı.',
    ),
  );

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

  Future<Result<List<CommentItem>>> listReplies(
    String commentId, {
    String? eventId,
  });

  /// Compatibility adapter for clients implementing the older complete-list
  /// contract. The HTTP repository overrides this with bounded server pages.
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    if (page < 0 || page > 1000 || size < 1 || size > 50) {
      return const Result.failure(
        AppError(
          code: 'engagement_comments_invalid_page',
          message: 'Geçersiz yorum sayfası.',
        ),
      );
    }
    final result = await listReplies(commentId, eventId: eventId);
    if (!result.isSuccess || result.data == null) {
      return Result.failure(
        result.error ??
            const AppError(
              code: 'engagement_comments_invalid_response',
              message: 'Yanıtlar doğrulanamadı.',
            ),
      );
    }
    final all = result.data!;
    final start = (page * size).clamp(0, all.length);
    final end = (start + size).clamp(start, all.length);
    return Result.success(
      CommentPage(
        items: List.unmodifiable(all.sublist(start, end)),
        totalElements: all.length,
        page: page,
        size: size,
      ),
    );
  }

  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  });

  Future<Result<void>> deleteComment({required String commentId});
}
