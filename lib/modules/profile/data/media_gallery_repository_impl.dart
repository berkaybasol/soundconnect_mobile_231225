import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/media_asset.dart';
import '../domain/media_gallery_repository.dart';
import 'models/media_asset_model.dart';

class MediaGalleryRepositoryImpl implements MediaGalleryRepository {
  final ApiClient _apiClient;

  MediaGalleryRepositoryImpl(this._apiClient);

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
