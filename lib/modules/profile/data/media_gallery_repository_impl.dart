import '../../../core/error/app_error.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/media_asset.dart';
import '../domain/entities/media_access.dart';
import '../domain/media_gallery_repository.dart';
import 'models/media_asset_model.dart';

class MediaGalleryRepositoryImpl implements MediaGalleryRepository {
  final ApiClient _apiClient;
  final AuthSessionManager? _sessions;

  MediaGalleryRepositoryImpl(this._apiClient, {AuthSessionManager? sessions})
    : _sessions = sessions;

  @override
  Future<Result<MediaAccess>> getAccess(String assetId) async {
    const denied = AppError(
      code: 'media_access_denied',
      message: 'Medya erişimi doğrulanamadı.',
    );
    final sessions = _sessions;
    final session = sessions?.session;
    if (sessions == null ||
        session == null ||
        !session.isAuthenticated ||
        !session.isActive ||
        session.requiresListenerProfileChoice ||
        session.userId?.isNotEmpty != true ||
        session.token?.isNotEmpty != true ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(assetId)) {
      return const Result.failure(denied);
    }
    var revoked = false;
    void observe() {
      if (!identical(session, sessions.session)) revoked = true;
    }

    sessions.addListener(observe);
    try {
      final result = await _apiClient.request<MediaAccess>(
        ApiHttpMethod.get,
        '/api/v1/user/media/$assetId/access-url',
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
        ),
        decoder: (value) => MediaAccess.fromJson(
          value,
          assetId: assetId,
          now: DateTime.now().toUtc(),
        ),
      );
      return revoked ? const Result.failure(denied) : Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(revoked ? denied : error.error);
    } catch (_) {
      return const Result.failure(denied);
    } finally {
      sessions.removeListener(observe);
    }
  }

  @override
  Future<Result<List<MediaAsset>>> listPublicImages({
    required String ownerType,
    required String ownerId,
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await _apiClient.get<List<MediaAsset>>(
        '/api/v1/public/media/owner/$ownerType/$ownerId/kind/IMAGE',
        query: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
        decoder: (json) {
          if (json is! Map<String, dynamic>) return const <MediaAsset>[];
          final content = json['content'];
          if (content is! List) return const <MediaAsset>[];
          return content
              .whereType<Map<String, dynamic>>()
              .map(MediaAssetModel.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'media_gallery_unknown',
          message: 'Fotograf galerisi getirilemedi',
        ),
      );
    }
  }
}
