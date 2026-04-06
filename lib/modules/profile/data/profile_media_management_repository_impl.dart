import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/profile_media_management_repository.dart';

class ProfileMediaManagementRepositoryImpl
    implements ProfileMediaManagementRepository {
  final ApiClient _apiClient;

  ProfileMediaManagementRepositoryImpl(this._apiClient);

  @override
  Future<Result<void>> addGalleryMedia({
    required String profileType,
    required String profileId,
    required String mediaAssetId,
    int? orderIndex,
  }) async {
    try {
      await _apiClient.post<Object?>(
        '/api/v1/profile-media',
        body: {
          'profileType': profileType,
          'profileId': profileId,
          'mediaAssetId': mediaAssetId,
          'role': 'GALLERY',
          'orderIndex': orderIndex,
        },
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'profile_media_add_unknown',
          message: 'Galeri medyasi profile eklenemedi',
        ),
      );
    }
  }
}
