import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/engagement_repository.dart';
import '../domain/entities/comment_item.dart';
import '../domain/entities/comment_page.dart';
import '../domain/entities/comment_like_state.dart';
import '../domain/entities/comment_text.dart';
import 'engagement_endpoints.dart';
import 'models/comment_item_model.dart';
import 'models/comment_wire_date.dart';

class EngagementRepositoryImpl implements EngagementRepository {
  final ApiClient _apiClient;

  final AuthSessionManager? _sessions;

  EngagementRepositoryImpl(this._apiClient, {AuthSessionManager? sessions})
    : _sessions = sessions;

  // Public EVENT adapters intentionally omit the JWT in DioApiClient. Their
  // counts are public, but likedByMe cannot represent a signed-in viewer.
  // Reuse the authenticated comment routes for eligible account projections.
  // A rejected token must fail authentication, never silently become a guest.
  bool get _canReadPersonalComments =>
      _sessions?.session.isAuthenticated == true &&
      _sessions?.session.isActive == true &&
      _sessions?.session.requiresListenerProfileChoice != true &&
      _sessions?.session.userId?.trim().isNotEmpty == true;

  @override
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) => _commentRequest(
    liked ? ApiHttpMethod.post : ApiHttpMethod.delete,
    () => EngagementEndpoints.commentLike(commentId),
    decoder: CommentLikeState.fromJson,
    errorCode: 'comment_like_unknown',
    errorMessage: 'Beğeni durumu doğrulanamadı.',
    validate: () => _validateCommentLikeId(commentId),
  );

  @override
  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) => _commentRequest(
    ApiHttpMethod.get,
    () => EngagementEndpoints.commentLikeState(commentId),
    decoder: CommentLikeState.fromJson,
    errorCode: 'comment_like_read_unknown',
    errorMessage: 'Beğeni durumu alınamadı.',
    validate: () => _validateCommentLikeId(commentId),
  );

  static void _validateCommentLikeId(String id) {
    if (id.trim().isEmpty || id != id.trim() || id.length > 128) {
      throw const FormatException('Invalid comment identity');
    }
  }

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) => _commentRequest(
    ApiHttpMethod.get,
    () => EngagementEndpoints.likeCount(targetType, targetId),
    decoder: _count,
    validate: () => _validateLikeTarget(targetType, targetId),
    errorCode: 'engagement_like_count_unknown',
    errorMessage: 'Beğeni sayısı getirilemedi.',
  );

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) => _commentRequest(
    ApiHttpMethod.get,
    () => EngagementEndpoints.isLiked(targetType, targetId),
    decoder: (raw) {
      if (raw is! bool) throw const FormatException('Invalid liked state');
      return raw;
    },
    validate: () => _validateLikeTarget(targetType, targetId),
    errorCode: 'engagement_is_liked_unknown',
    errorMessage: 'Beğeni durumu getirilemedi.',
  );

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) => _commentRequest<void>(
    ApiHttpMethod.post,
    () => EngagementEndpoints.like(targetType, targetId),
    decoder: (_) {},
    validate: () => _validateLikeTarget(targetType, targetId),
    errorCode: 'engagement_like_unknown',
    errorMessage: 'Beğeni doğrulanamadı. Yenilemek için tekrar dene.',
  );

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) => _commentRequest<void>(
    ApiHttpMethod.delete,
    () => EngagementEndpoints.unlike(targetType, targetId),
    decoder: (_) {},
    validate: () => _validateLikeTarget(targetType, targetId),
    errorCode: 'engagement_unlike_unknown',
    errorMessage: 'Beğeni doğrulanamadı. Yenilemek için tekrar dene.',
  );

  static void _validateLikeTarget(String type, String id) {
    if (!const {
      'EVENT',
      'EVENT_POST',
      'TABLE_GROUP_POST',
      'MEDIA',
      'OVERTHINKING',
      'COMMENT',
    }.contains(type)) {
      throw const FormatException('Invalid engagement target');
    }
    _validateCommentLikeId(id);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) {
    final publicEventRead = targetType == 'EVENT' && !_canReadPersonalComments;
    return _commentRequest(
      ApiHttpMethod.get,
      () => publicEventRead
          ? '/api/v1/events/${Uri.encodeComponent(targetId)}/comments'
          : EngagementEndpoints.listComments(targetType, targetId),
      publicRead: publicEventRead,
      query: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
      validate: () => _validatePage(page, size),
      decoder: (raw) => _commentPageFromJson(raw, page, size, roots: true),
      errorCode: 'engagement_comments_unknown',
      errorMessage: 'Yorumlar getirilemedi. Yeniden dene.',
    );
  }

  @override
  Future<Result<List<CommentItem>>> listReplies(
    String commentId, {
    String? eventId,
  }) async {
    final result = await listReplyPage(commentId, eventId: eventId, size: 50);
    return result.isSuccess && result.data != null
        ? Result.success(result.data!.items)
        : Result.failure(result.error ?? _invalidResponse);
  }

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) {
    final publicEventRead = eventId != null && !_canReadPersonalComments;
    return _commentRequest(
      ApiHttpMethod.get,
      () => publicEventRead
          ? '/api/v1/events/${Uri.encodeComponent(eventId)}/comments/'
                '${Uri.encodeComponent(commentId)}/replies'
          : EngagementEndpoints.listReplies(commentId),
      publicRead: publicEventRead,
      query: {'page': page, 'size': size, 'sort': 'createdAt,asc'},
      validate: () => _validatePage(page, size),
      decoder: (raw) => _commentPageFromJson(
        raw,
        page,
        size,
        parentCommentId: commentId,
        allowLegacyList: true,
      ),
      errorCode: 'engagement_comment_replies_unknown',
      errorMessage: 'Yanıtlar getirilemedi. Yeniden dene.',
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) => _commentRequest(
    ApiHttpMethod.post,
    () => EngagementEndpoints.createComment(targetType, targetId),
    body: {'text': text.trim(), 'parentCommentId': parentCommentId},
    validate: () {
      if (!CommentText.isValid(text)) {
        throw const FormatException('Invalid comment text');
      }
    },
    decoder: (raw) => _commentFromJson(raw, expectedParent: parentCommentId),
    commentCreation: true,
    errorCode: 'engagement_comment_create_unknown',
    errorMessage:
        'Yorumun kaydedildiği doğrulanamadı. Yeniden göndermeden önce yorumları kontrol et.',
  );

  @override
  Future<Result<void>> deleteComment({required String commentId}) =>
      _commentRequest<void>(
        ApiHttpMethod.delete,
        () => EngagementEndpoints.deleteComment(commentId),
        decoder: (_) {},
        errorCode: 'engagement_comment_delete_unknown',
        errorMessage: 'Yorum silinemedi. Yeniden dene.',
      );

  static const _invalidResponse = AppError(
    code: 'engagement_comments_invalid_response',
    message: 'Yorumlar doğrulanamadı. Yeniden dene.',
  );
  static const _sessionError = AppError(
    code: 'engagement_comment_session_changed',
    message: 'Oturum değişti. Yorumları yeniden yükle.',
  );

  Future<Result<T>> _commentRequest<T>(
    ApiHttpMethod method,
    String Function() path, {
    required T Function(Object?) decoder,
    required String errorCode,
    required String errorMessage,
    Map<String, dynamic>? query,
    Object? body,
    bool publicRead = false,
    bool commentCreation = false,
    void Function()? validate,
  }) async {
    final session = _sessions?.session;
    bool current() =>
        _sessions == null || identical(_sessions.session, session);
    if (_sessions != null &&
        !publicRead &&
        (session?.isAuthenticated != true ||
            session?.isActive != true ||
            session?.userId?.trim().isNotEmpty != true ||
            session?.requiresListenerProfileChoice == true)) {
      return const Result.failure(_sessionError);
    }
    try {
      validate?.call();
      final value = await _apiClient.request<T>(
        method,
        path(),
        query: query,
        body: body,
        decoder: decoder,
        requestContext: session == null
            ? null
            : ApiRequestContext(
                expectedSessionKey: session.isAuthenticated
                    ? session.userId
                    : null,
                expectedToken: session.isAuthenticated ? session.token : null,
                requireGuestSession: !session.isAuthenticated,
              ),
      );
      return current()
          ? Result.success(value)
          : const Result.failure(_sessionError);
    } on ApiException catch (error) {
      if (!current()) return const Result.failure(_sessionError);
      if (commentCreation) {
        final guardError = _commentGuardError(error.error);
        if (guardError != null) return Result.failure(guardError);
      }
      final status = int.tryParse(error.error.code);
      if (commentCreation &&
          (error.error.code == 'network' ||
              error.error.code == '9999' || // Server INTERNAL_ERROR.
              (status != null && status >= 500 && status < 600))) {
        return Result.failure(
          AppError(
            code: error.error.code,
            message:
                'Sonuç doğrulanamadı. Tekrar göndermeden yorumları kontrol et.',
            retryAfter: error.error.retryAfter,
          ),
        );
      }
      return Result.failure(error.error);
    } catch (_) {
      return Result.failure(
        current()
            ? AppError(code: errorCode, message: errorMessage)
            : _sessionError,
      );
    }
  }

  static AppError? _commentGuardError(AppError error) {
    // Only these server guard codes guarantee that no comment was saved.
    // Unknown 503/network failures must retain the ambiguous-write warning.
    final delay = error.retryAfter;
    final seconds = delay != null && delay > Duration.zero
        ? (delay.inMicroseconds / Duration.microsecondsPerSecond).ceil()
        : null;
    final message = switch (error.code) {
      '9356' =>
        'Bu içerikte art arda birkaç yorum gönderdin. '
            '${seconds == null ? 'Biraz bekleyip' : '$seconds saniye bekleyip'} '
            'tekrar deneyebilirsin.',
      '9357' =>
        'Yorum şu anda gönderilemiyor. Biraz sonra tekrar deneyebilirsin.',
      _ => null,
    };
    if (message == null) return null;
    return AppError(
      code: error.code,
      message: message,
      details: error.details,
      retryAfter: error.retryAfter,
    );
  }

  static void _validatePage(int page, int size) {
    if (page < 0 || page > 1000 || size < 1 || size > 50) {
      throw const FormatException('Invalid comments page');
    }
  }

  static int _count(Object? raw) {
    if (raw is! int || raw < 0 || raw > 9007199254740991) {
      throw const FormatException('Invalid comment count');
    }
    return raw;
  }

  static CommentItem _commentFromJson(Object? raw, {String? expectedParent}) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid comment');
    }
    if (raw['id'] is! String ||
        (raw['id'] as String).trim().isEmpty ||
        raw['text'] is! String) {
      throw const FormatException('Missing comment identity or text');
    }
    for (final field in ['deleted', 'anonymousAuthor']) {
      if (raw.containsKey(field) && raw[field] is! bool) {
        throw const FormatException('Invalid comment flag');
      }
    }
    if (raw.containsKey('replyCount')) _count(raw['replyCount']);
    final parent = raw['parentCommentId'];
    if (parent != null && (parent is! String || parent.trim().isEmpty)) {
      throw const FormatException('Invalid parent identity');
    }
    final instant = raw['createdAt'];
    if (instant != null &&
        (instant is! String || parseCommentWireDate(instant) == null)) {
      throw const FormatException('Invalid comment timestamp');
    }
    final user = raw['user'];
    if (user != null) {
      if (user is! Map<String, dynamic>) {
        throw const FormatException('Invalid comment author');
      }
      for (final field in [
        'id',
        'username',
        'avatarUrl',
        'profilePictureUrl',
        'profileImageUrl',
      ]) {
        if (user[field] != null && user[field] is! String) {
          throw const FormatException('Invalid author field');
        }
      }
    }
    final item = CommentItemModel.fromJson(raw);
    if (raw.containsKey('parentCommentId') &&
        item.parentCommentId != expectedParent) {
      throw const FormatException('Comment parent scope mismatch');
    }
    return item;
  }

  CommentPage _commentPageFromJson(
    Object? raw,
    int page,
    int size, {
    bool roots = false,
    String? parentCommentId,
    bool allowLegacyList = false,
  }) {
    final Map<String, dynamic> map;
    if (raw is List && allowLegacyList && page == 0) {
      map = {'content': raw, 'totalElements': raw.length};
    } else if (raw is Map<String, dynamic>) {
      map = raw;
    } else {
      throw const FormatException('Invalid comment page');
    }
    final content = map['content'];
    final total = _count(map['totalElements']);
    if (content is! List ||
        content.length > size ||
        total < content.length ||
        (content.isEmpty && page * size < total) ||
        (map.containsKey('number') && _count(map['number']) != page) ||
        (map.containsKey('size') && _count(map['size']) != size) ||
        (map.containsKey('totalPages') &&
            _count(map['totalPages']) != (total / size).ceil()) ||
        (map.containsKey('first') && map['first'] != (page == 0)) ||
        (map.containsKey('last') &&
            map['last'] != ((page + 1) * size >= total))) {
      throw const FormatException('Invalid comment pagination');
    }
    final ids = <String>{};
    final items = <CommentItem>[];
    for (final rawItem in content) {
      final item = _commentFromJson(
        rawItem,
        expectedParent: roots ? null : parentCommentId,
      );
      if (!ids.add(item.id)) throw const FormatException('Duplicate comment');
      items.add(item);
    }
    return CommentPage(
      items: List.unmodifiable(items),
      totalElements: total,
      page: page,
      size: size,
    );
  }
}
