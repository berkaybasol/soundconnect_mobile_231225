import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/profile_media_repository.dart';
import '../domain/entities/media_asset.dart';
import '../domain/entities/profile_media.dart';
import 'models/media_asset_model.dart';
import 'models/profile_media_model.dart';
import 'profile_media_endpoints.dart';

class ProfileMediaRepositoryImpl implements ProfileMediaRepository {
  final ApiClient _apiClient;

  ProfileMediaRepositoryImpl(this._apiClient);

  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async {
    try {
      final response = await _apiClient.get<ProfileMedia>(
        ProfileMediaEndpoints.media(
          profileType: profileType,
          profileId: profileId,
        ),
        decoder: (json) => ProfileMediaModel.fromJson(
          json as Map<String, dynamic>,
        ),
      );

      ProfileMedia finalMedia = response;
      if (profileType.toUpperCase() == 'MUSICIAN' &&
          response.featuredVideo == null &&
          response.videos.isEmpty) {
        final fallbackVideos = await _loadPublicVideos(profileId);
        if (fallbackVideos.isNotEmpty) {
          finalMedia = ProfileMedia(
            featuredVideo: null,
            videos: fallbackVideos,
            audios: response.audios,
          );
        }
      }

      return Result.success(finalMedia);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'profile_media_unknown',
        message: 'Profil medyasi getirilemedi',
      ));
    }
  }

  Future<List<MediaAsset>> _loadPublicVideos(String profileId) async {
    try {
      return await _apiClient.get<List<MediaAssetModel>>(
        '/api/v1/public/media/owner/MUSICIAN_PROFILE/$profileId/kind/VIDEO',
        query: const {
          'page': 0,
          'size': 20,
          'sort': 'createdAt,desc',
        },
        decoder: (json) {
          if (json is! Map<String, dynamic>) return const <MediaAssetModel>[];
          final content = json['content'];
          if (content is! List) return const <MediaAssetModel>[];
          return content
              .whereType<Map<String, dynamic>>()
              .map(MediaAssetModel.fromJson)
              .toList();
        },
      );
    } catch (_) {
      return const <MediaAsset>[];
    }
  }
}
