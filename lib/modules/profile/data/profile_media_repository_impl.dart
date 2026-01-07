import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/profile_media_repository.dart';
import '../domain/entities/profile_media.dart';
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
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'profile_media_unknown',
        message: 'Profil medyasi getirilemedi',
      ));
    }
  }
}
