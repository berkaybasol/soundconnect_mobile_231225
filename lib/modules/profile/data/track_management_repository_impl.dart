import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/track_management_repository.dart';

class TrackManagementRepositoryImpl implements TrackManagementRepository {
  final ApiClient _apiClient;

  TrackManagementRepositoryImpl(this._apiClient);

  @override
  Future<Result<void>> createTrack({
    required String profileId,
    required String ownerType,
    required String mediaAssetId,
    required String title,
  }) async {
    try {
      final endpoint = switch (ownerType) {
        'BAND' => '/api/v1/bands/$profileId/tracks',
        _ => '/api/v1/musician-profiles/$profileId/tracks',
      };
      await _apiClient.post<Object?>(
        endpoint,
        body: {
          'mediaAssetId': mediaAssetId,
          'title': title,
          'durationSeconds': null,
          'bpm': null,
        },
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'track_create_unknown',
          message: 'Sarki eklenemedi',
        ),
      );
    }
  }
}
