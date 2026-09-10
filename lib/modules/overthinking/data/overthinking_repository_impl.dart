import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/entities/overthinking_post.dart';
import '../domain/entities/overthinking_reveal_request.dart';
import '../domain/entities/overthinking_incoming_unread_status.dart';
import '../domain/overthinking_repository.dart';
import '../domain/overthinking_feed_sort.dart';
import 'models/overthinking_post_model.dart';
import 'models/overthinking_reveal_request_model.dart';
import 'overthinking_endpoints.dart';

class OverthinkingRepositoryImpl implements OverthinkingRepository {
  final ApiClient _apiClient;
  final AuthSessionManager? _sessions;

  OverthinkingRepositoryImpl(this._apiClient, {AuthSessionManager? sessions})
    : _sessions = sessions;

  static const _sessionError = AppError(
    code: 'overthinking_session_changed',
    message: 'Oturum değişti. Overthinking sayfasını yeniden aç.',
  );

  Future<T> _request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    bool publicRead = false,
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
      throw ApiException(_sessionError);
    }
    try {
      final result = await _apiClient.request<T>(
        method,
        path,
        body: body,
        query: query,
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
      if (!current()) throw ApiException(_sessionError);
      return result;
    } catch (_) {
      if (!current()) throw ApiException(_sessionError);
      rethrow;
    }
  }

  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
    OverthinkingFeedSort sort = OverthinkingFeedSort.newest,
  }) async {
    return _fetchPostPage(
      path: OverthinkingEndpoints.feed,
      page: page,
      size: size,
      fallbackCode: 'overthinking_feed_unknown',
      fallbackMessage: 'Overthinking akisi getirilemedi',
      publicRead: true,
      feedSort: sort,
    );
  }

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) {
    return _fetchPostPage(
      path: OverthinkingEndpoints.myPosts,
      page: page,
      size: size,
      fallbackCode: 'overthinking_my_posts_unknown',
      fallbackMessage: 'Paylasimlarin getirilemedi',
    );
  }

  @override
  Future<Result<Page<OverthinkingPost>>> getPostsByArtist({
    required String artistId,
    int page = 0,
    int size = 20,
  }) {
    return _fetchPostPage(
      path: OverthinkingEndpoints.postsByArtist(artistId),
      page: page,
      size: size,
      fallbackCode: 'overthinking_artist_posts_unknown',
      fallbackMessage: 'Sanatci paylasimlari getirilemedi',
      publicRead: true,
    );
  }

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    try {
      final response = await _request<OverthinkingPost>(
        ApiHttpMethod.get,
        OverthinkingEndpoints.detail(postId),
        publicRead: true,
        decoder: (json) =>
            OverthinkingPostModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'overthinking_detail_unknown',
          message: 'Paylasim detayi getirilemedi',
        ),
      );
    }
  }

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
  }) async {
    try {
      final response = await _request<OverthinkingPost>(
        ApiHttpMethod.post,
        OverthinkingEndpoints.create,
        body: {
          if (clientRequestId != null) 'clientRequestId': clientRequestId,
          'title': title,
          'content': content,
          'visibilityType': visibilityType,
          'spotifyTrackUrl': spotifyTrackUrl,
          'spotifyArtistId': spotifyArtistId,
          'spotifyTrackName': spotifyTrackName,
          'spotifyArtistName': spotifyArtistName,
          'spotifyAlbumImageUrl': spotifyAlbumImageUrl,
          'musicianTrackId': null,
          'bandTrackId': null,
        },
        decoder: (json) =>
            OverthinkingPostModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'overthinking_create_unknown',
          message: 'Paylasim olusturulamadi',
        ),
      );
    }
  }

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
  }) async {
    try {
      final response = await _request<OverthinkingPost>(
        ApiHttpMethod.put,
        OverthinkingEndpoints.update(postId),
        body: {
          'title': title,
          'content': content,
          'visibilityType': visibilityType,
          'spotifyTrackUrl': spotifyTrackUrl,
          'spotifyArtistId': spotifyArtistId,
          'spotifyTrackName': spotifyTrackName,
          'spotifyArtistName': spotifyArtistName,
          'spotifyAlbumImageUrl': spotifyAlbumImageUrl,
          'musicianTrackId': musicianTrackId,
          'bandTrackId': bandTrackId,
        },
        decoder: (json) =>
            OverthinkingPostModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'overthinking_update_unknown',
          message: 'Paylasim guncellenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> deletePost({required String postId}) async {
    try {
      await _request<Object?>(
        ApiHttpMethod.delete,
        OverthinkingEndpoints.delete(postId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'overthinking_delete_unknown',
          message: 'Paylasim silinemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> requestReveal({required String postId}) async {
    try {
      await _request<Object?>(
        ApiHttpMethod.post,
        OverthinkingEndpoints.createRevealRequest(postId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'overthinking_reveal_unknown',
          message: 'Goruntuleme istegi gonderilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> cancelReveal({required String postId}) async {
    try {
      await _request<Object?>(
        ApiHttpMethod.delete,
        OverthinkingEndpoints.cancelRevealRequest(postId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'overthinking_reveal_cancel_unknown',
          message: 'Kimlik isteği geri alınamadı.',
        ),
      );
    }
  }

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) {
    return _fetchRevealPage(
      path: OverthinkingEndpoints.incomingRevealRequests,
      page: page,
      size: size,
      fallbackCode: 'overthinking_incoming_reveal_unknown',
      fallbackMessage: 'Gelen kimlik istekleri getirilemedi',
    );
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> getIncomingUnreadStatus() =>
      _incomingUnreadRequest(
        ApiHttpMethod.get,
        OverthinkingEndpoints.incomingUnreadStatus,
      );

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) => _incomingUnreadRequest(
    ApiHttpMethod.post,
    OverthinkingEndpoints.incomingSeen,
    revision: revision,
  );

  Future<Result<OverthinkingIncomingUnreadStatus>> _incomingUnreadRequest(
    ApiHttpMethod method,
    String path, {
    int? revision,
  }) async {
    try {
      if (revision != null && revision < 0) {
        throw const FormatException('Invalid inbox revision');
      }
      final status = await _request<OverthinkingIncomingUnreadStatus>(
        method,
        path,
        body: revision == null ? null : {'revision': revision},
        decoder: (json) {
          final unread = json is Map<String, dynamic>
              ? json['hasUnread']
              : null;
          final serverRevision = json is Map<String, dynamic>
              ? json['revision']
              : null;
          if (unread is! bool || serverRevision is! int || serverRevision < 0) {
            throw const FormatException(
              'Invalid incoming request unread status',
            );
          }
          return OverthinkingIncomingUnreadStatus(
            hasUnread: unread,
            revision: serverRevision,
          );
        },
      );
      return Result.success(status);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'overthinking_incoming_unread_unknown',
          message: 'Yeni kimlik isteklerinin durumu doğrulanamadı.',
        ),
      );
    }
  }

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) {
    return _fetchRevealPage(
      path: OverthinkingEndpoints.sentRevealRequests,
      page: page,
      size: size,
      fallbackCode: 'overthinking_sent_reveal_unknown',
      fallbackMessage: 'Gonderilen kimlik istekleri getirilemedi',
    );
  }

  @override
  Future<Result<OverthinkingRevealRequest>> approveRevealRequest({
    required String requestId,
  }) {
    return _postRevealAction(
      path: OverthinkingEndpoints.approveRevealRequest(requestId),
      fallbackCode: 'overthinking_reveal_approve_unknown',
      fallbackMessage: 'Kimlik istegi kabul edilemedi',
    );
  }

  @override
  Future<Result<OverthinkingRevealRequest>> rejectRevealRequest({
    required String requestId,
  }) {
    return _postRevealAction(
      path: OverthinkingEndpoints.rejectRevealRequest(requestId),
      fallbackCode: 'overthinking_reveal_reject_unknown',
      fallbackMessage: 'Kimlik istegi reddedilemedi',
    );
  }

  Future<Result<Page<OverthinkingPost>>> _fetchPostPage({
    required String path,
    required int page,
    required int size,
    required String fallbackCode,
    required String fallbackMessage,
    bool publicRead = false,
    OverthinkingFeedSort? feedSort,
  }) async {
    try {
      final response = await _request<Page<OverthinkingPost>>(
        ApiHttpMethod.get,
        path,
        publicRead: publicRead,
        query: {
          'page': page,
          'size': size,
          if (feedSort != null) 'order': feedSort.apiValue,
          if (feedSort == null) 'sort': 'createdAt,desc',
        },
        decoder: (json) => _decodePage(
          json,
          page,
          (item) => OverthinkingPostModel.fromJson(item),
        ),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(code: fallbackCode, message: fallbackMessage),
      );
    }
  }

  Future<Result<Page<OverthinkingRevealRequest>>> _fetchRevealPage({
    required String path,
    required int page,
    required int size,
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _request<Page<OverthinkingRevealRequest>>(
        ApiHttpMethod.get,
        path,
        query: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
        decoder: (json) => _decodePage(
          json,
          page,
          (item) => OverthinkingRevealRequestModel.fromJson(item),
        ),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(code: fallbackCode, message: fallbackMessage),
      );
    }
  }

  Future<Result<OverthinkingRevealRequest>> _postRevealAction({
    required String path,
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _request<OverthinkingRevealRequest>(
        ApiHttpMethod.post,
        path,
        decoder: (json) => OverthinkingRevealRequestModel.fromJson(
          json as Map<String, dynamic>,
        ),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(code: fallbackCode, message: fallbackMessage),
      );
    }
  }

  Page<T> _decodePage<T>(
    Object? json,
    int fallbackPage,
    T Function(Map<String, dynamic> item) itemDecoder,
  ) {
    final map = json as Map<String, dynamic>? ?? const {};
    final content = (map['content'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(itemDecoder)
        .toList();
    final currentPage = (map['number'] as num?)?.toInt() ?? fallbackPage;
    final bool hasNext = map['last'] is bool
        ? !(map['last'] as bool)
        : (map['hasNext'] as bool?) ?? false;
    return Page<T>(
      items: content,
      hasNext: hasNext,
      nextCursor: hasNext ? (currentPage + 1).toString() : null,
    );
  }
}
