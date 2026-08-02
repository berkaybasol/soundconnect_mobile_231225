import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/listener_profile.dart';
import '../domain/listener_profile_repository.dart';
import 'listener_profile_endpoints.dart';
import 'models/listener_profile_model.dart';

class ListenerProfileRepositoryImpl implements ListenerProfileRepository {
  final ApiClient _apiClient;

  ListenerProfileRepositoryImpl(this._apiClient);

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    try {
      final response = await _apiClient.get<ListenerProfile>(
        ListenerProfileEndpoints.me,
        decoder: (json) =>
            ListenerProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'listener_profile_unknown',
          message: 'Listener profili getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async {
    try {
      final response = await _apiClient.put<ListenerProfile>(
        ListenerProfileEndpoints.update,
        body: request.toJson(),
        decoder: (json) =>
            ListenerProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'listener_profile_update_unknown',
          message: 'Listener profili güncellenemedi',
        ),
      );
    }
  }
}
