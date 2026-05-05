import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/entities/overthinking_post.dart';
import '../domain/entities/overthinking_reveal_request.dart';
import '../domain/overthinking_repository.dart';
import 'models/overthinking_post_model.dart';
import 'models/overthinking_reveal_request_model.dart';
import 'overthinking_endpoints.dart';

class OverthinkingRepositoryImpl implements OverthinkingRepository {
  final ApiClient _apiClient;

  OverthinkingRepositoryImpl(this._apiClient);

  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
  }) async {
    return _fetchPostPage(
      path: OverthinkingEndpoints.feed,
      page: page,
      size: size,
      fallbackCode: 'overthinking_feed_unknown',
      fallbackMessage: 'Overthinking akisi getirilemedi',
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
    );
  }

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    try {
      final response = await _apiClient.get<OverthinkingPost>(
        OverthinkingEndpoints.detail(postId),
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
      final response = await _apiClient.post<OverthinkingPost>(
        OverthinkingEndpoints.create,
        body: {
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
      final response = await _apiClient.put<OverthinkingPost>(
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
      await _apiClient.delete<Object?>(
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
      await _apiClient.post<Object?>(
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
  }) async {
    try {
      final response = await _apiClient.get<Page<OverthinkingPost>>(
        path,
        query: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
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
      final response = await _apiClient.get<Page<OverthinkingRevealRequest>>(
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
      final response = await _apiClient.post<OverthinkingRevealRequest>(
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
