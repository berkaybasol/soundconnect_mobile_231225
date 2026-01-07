import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/musician_profile_repository.dart';
import '../domain/entities/musician_profile.dart';
import 'models/musician_profile_model.dart';
import 'models/musician_profile_save_request.dart';
import 'musician_profile_endpoints.dart';

class MusicianProfileRepositoryImpl implements MusicianProfileRepository {
  final ApiClient _apiClient;

  MusicianProfileRepositoryImpl(this._apiClient);

  @override
  Future<Result<MusicianProfile>> getMyProfile() async {
    try {
      final response = await _apiClient.get<MusicianProfile>(
        MusicianProfileEndpoints.me,
        decoder: (json) => MusicianProfileModel.fromJson(
          json as Map<String, dynamic>,
        ),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'musician_profile_unknown',
        message: 'Profil getirilemedi',
      ));
    }
  }

  @override
  Future<Result<MusicianProfile>> updateMyProfile(
    MusicianProfileSaveRequest request,
  ) async {
    try {
      final response = await _apiClient.put<MusicianProfile>(
        MusicianProfileEndpoints.update,
        body: request.toJson(),
        decoder: (json) => MusicianProfileModel.fromJson(
          json as Map<String, dynamic>,
        ),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'musician_profile_update_unknown',
        message: 'Profil guncellenemedi',
      ));
    }
  }
}
