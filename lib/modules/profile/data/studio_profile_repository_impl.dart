import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/studio_profile.dart';
import '../domain/studio_profile_repository.dart';
import 'models/studio_profile_model.dart';
import 'studio_profile_endpoints.dart';

class StudioProfileRepositoryImpl implements StudioProfileRepository {
  final ApiClient _apiClient;

  StudioProfileRepositoryImpl(this._apiClient);

  @override
  Future<Result<StudioProfile>> getMyProfile() async {
    try {
      final response = await _apiClient.get<StudioProfile>(
        StudioProfileEndpoints.me,
        decoder: (json) =>
            StudioProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'studio_profile_unknown',
          message: 'Studio profili getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<StudioProfile>> getPublicProfile(String profileId) async {
    try {
      final response = await _apiClient.get<StudioProfile>(
        StudioProfileEndpoints.publicDetail(profileId),
        decoder: (json) =>
            StudioProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'studio_public_profile_unknown',
          message: 'Studio profili getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<StudioProfile>> updateMyProfile(
    StudioProfileSaveRequest request,
  ) async {
    try {
      final response = await _apiClient.put<StudioProfile>(
        StudioProfileEndpoints.update,
        body: request.toJson(),
        decoder: (json) =>
            StudioProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'studio_profile_update_unknown',
          message: 'Studio profili guncellenemedi',
        ),
      );
    }
  }
}
