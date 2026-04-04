import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/band_follow_repository.dart';
import 'band_follow_endpoints.dart';

class BandFollowRepositoryImpl implements BandFollowRepository {
  final ApiClient _apiClient;

  BandFollowRepositoryImpl(this._apiClient);

  @override
  Future<Result<int>> getFollowersCount(String bandId) async {
    try {
      final response = await _apiClient.get<int>(
        BandFollowEndpoints.countFollowers(bandId),
        decoder: (json) => (json as num?)?.toInt() ?? 0,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_follow_count_followers_unknown',
          message: 'Band follower count could not be loaded',
        ),
      );
    }
  }
}
