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
        decoder: (json) =>
            ProfileMediaModel.fromJson(json as Map<String, dynamic>),
      );

      ProfileMedia finalMedia = response;
      if (response.featuredVideo == null && response.videos.isEmpty) {
        final fallbackMedia = await _loadPublicMedia(
          profileType: profileType,
          profileId: profileId,
        );
        if (fallbackMedia != null && fallbackMedia.isNotEmpty) {
          finalMedia = ProfileMedia(
            featuredVideo: null,
            videos: fallbackMedia,
            audios: response.audios,
          );
        }
      }

      return Result.success(finalMedia);
    } on ApiException catch (e) {
      final fallbackMedia = await _loadPublicMedia(
        profileType: profileType,
        profileId: profileId,
      );
      if (fallbackMedia != null) {
        return Result.success(
          ProfileMedia(
            featuredVideo: null,
            videos: fallbackMedia,
            audios: const [],
          ),
        );
      }
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'profile_media_unknown',
          message: 'Profil medyasi getirilemedi',
        ),
      );
    }
  }

  Future<List<MediaAsset>?> _loadPublicMedia({
    required String profileType,
    required String profileId,
  }) async {
    try {
      return await _apiClient.get<List<MediaAssetModel>>(
        '/api/v1/public/media/owner/${_mediaOwnerType(profileType)}/$profileId/kind/VIDEO',
        query: const {'page': 0, 'size': 20, 'sort': 'createdAt,desc'},
        decoder: (json) {
          if (json is! Map<String, dynamic>) return const <MediaAssetModel>[];
          final content = json['content'];
          if (content is! List) return const <MediaAssetModel>[];
          return content
              .whereType<Map<String, dynamic>>()
              .map(MediaAssetModel.fromJson)
              .where(
                (item) =>
                    item.id.isNotEmpty &&
                    (item.kind ?? '').toUpperCase() == 'VIDEO',
              )
              .toList();
        },
      );
    } catch (_) {
      return null;
    }
  }

  String _mediaOwnerType(String profileType) {
    return switch (profileType.trim().toUpperCase()) {
      'BAND' => 'BAND',
      'VENUE' => 'VENUE_PROFILE',
      'STUDIO' => 'STUDIO_PROFILE',
      'LISTENER' => 'LISTENER_PROFILE',
      'PRODUCER' => 'PRODUCER_PROFILE',
      'ORGANIZER' => 'ORGANIZER_PROFILE',
      _ => 'MUSICIAN_PROFILE',
    };
  }
}
