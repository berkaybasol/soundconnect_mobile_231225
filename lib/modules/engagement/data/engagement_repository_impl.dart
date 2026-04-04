import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/engagement_repository.dart';
import '../domain/entities/comment_item.dart';
import '../domain/entities/comment_page.dart';
import 'engagement_endpoints.dart';
import 'models/comment_item_model.dart';

class EngagementRepositoryImpl implements EngagementRepository {
  final ApiClient _apiClient;

  EngagementRepositoryImpl(this._apiClient);

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final response = await _apiClient.get<int>(
        EngagementEndpoints.likeCount(targetType, targetId),
        decoder: (json) => (json as num?)?.toInt() ?? 0,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_like_count_unknown',
        message: 'Like sayisi getirilemedi',
      ));
    }
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final response = await _apiClient.get<bool>(
        EngagementEndpoints.isLiked(targetType, targetId),
        decoder: (json) => json == true,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_is_liked_unknown',
        message: 'Begeni durumu getirilemedi',
      ));
    }
  }

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    try {
      await _apiClient.post<Object?>(
        EngagementEndpoints.like(targetType, targetId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_like_unknown',
        message: 'Begeni eklenemedi',
      ));
    }
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    try {
      await _apiClient.delete<Object?>(
        EngagementEndpoints.unlike(targetType, targetId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_unlike_unknown',
        message: 'Beğeni kaldırılamadı',
      ));
    }
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get<CommentPage>(
        EngagementEndpoints.listComments(targetType, targetId),
        query: {
          'page': page,
          'size': size,
          'sort': 'createdAt,desc',
        },
        decoder: (json) => _commentPageFromJson(json),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_comments_unknown',
        message: 'Yorumlar getirilemedi',
      ));
    }
  }

  @override
  Future<Result<List<CommentItem>>> listReplies(String commentId) async {
    try {
      final response = await _apiClient.get<List<CommentItem>>(
        '/api/v1/comments/replies/$commentId',
        decoder: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map(CommentItemModel.fromJson)
                .toList();
          }
          final map = json as Map<String, dynamic>? ?? <String, dynamic>{};
          final content = map['content'];
          if (content is List) {
            return content
                .whereType<Map<String, dynamic>>()
                .map(CommentItemModel.fromJson)
                .toList();
          }
          return const <CommentItem>[];
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_comment_replies_unknown',
        message: 'Yanıtlar getirilemedi',
      ));
    }
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      final response = await _apiClient.post<CommentItem>(
        EngagementEndpoints.createComment(targetType, targetId),
        body: {
          'text': text,
          'parentCommentId': parentCommentId,
        },
        decoder: (json) =>
            CommentItemModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_comment_create_unknown',
        message: 'Yorum gönderilemedi',
      ));
    }
  }

  @override
  Future<Result<void>> deleteComment({required String commentId}) async {
    try {
      await _apiClient.delete<Object?>(
        EngagementEndpoints.deleteComment(commentId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'engagement_comment_delete_unknown',
        message: 'Yorum silinemedi',
      ));
    }
  }

  CommentPage _commentPageFromJson(Object? json) {
    final map = json as Map<String, dynamic>? ?? {};
    final content = map['content'] as List<dynamic>? ?? const [];
    final items = content
        .whereType<Map<String, dynamic>>()
        .map(CommentItemModel.fromJson)
        .toList();
    final totalElements = (map['totalElements'] as num?)?.toInt() ?? items.length;
    return CommentPage(items: items, totalElements: totalElements);
  }
}
