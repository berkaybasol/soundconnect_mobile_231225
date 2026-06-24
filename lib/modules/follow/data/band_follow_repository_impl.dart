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
  Future<Result<void>> followBand(String bandId) async {
    try {
      await _apiClient.post<Object?>(
        BandFollowEndpoints.band(bandId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_follow_action_unknown',
          message: 'Band could not be followed',
        ),
      );
    }
  }

  @override
  Future<Result<void>> unfollowBand(String bandId) async {
    try {
      await _apiClient.delete<Object?>(
        BandFollowEndpoints.band(bandId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_unfollow_action_unknown',
          message: 'Band could not be unfollowed',
        ),
      );
    }
  }

  @override
  Future<Result<bool>> isFollowingBand(String bandId) async {
    try {
      final response = await _apiClient.get<bool>(
        BandFollowEndpoints.isFollowing(bandId),
        decoder: (json) => json == true,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_follow_status_unknown',
          message: 'Band follow status could not be loaded',
        ),
      );
    }
  }

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
