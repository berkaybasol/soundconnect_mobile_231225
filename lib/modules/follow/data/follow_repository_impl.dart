import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/follow_repository.dart';
import 'follow_endpoints.dart';
import 'models/follow_request.dart';

class FollowRepositoryImpl implements FollowRepository {
  final ApiClient _apiClient;

  FollowRepositoryImpl(this._apiClient);

  @override
  Future<Result<int>> getFollowersCount(String userId) async {
    try {
      final response = await _apiClient.get<int>(
        FollowEndpoints.countFollowers(userId),
        decoder: (json) => (json as num?)?.toInt() ?? 0,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'follow_count_followers_unknown',
        message: 'Followers count could not be loaded',
      ));
    }
  }

  @override
  Future<Result<int>> getFollowingCount(String userId) async {
    try {
      final response = await _apiClient.get<int>(
        FollowEndpoints.countFollowing(userId),
        decoder: (json) => (json as num?)?.toInt() ?? 0,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'follow_count_following_unknown',
        message: 'Following count could not be loaded',
      ));
    }
  }

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _apiClient.post<Object?>(
        FollowEndpoints.follow,
        body: FollowRequest(
          followerId: followerId,
          followingId: followingId,
        ).toJson(),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'follow_action_unknown',
        message: 'Follow action failed',
      ));
    }
  }

  @override
  Future<Result<void>> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _apiClient.post<Object?>(
        FollowEndpoints.unfollow,
        body: FollowRequest(
          followerId: followerId,
          followingId: followingId,
        ).toJson(),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'unfollow_action_unknown',
        message: 'Unfollow action failed',
      ));
    }
  }

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final response = await _apiClient.get<bool>(
        FollowEndpoints.isFollowing(followerId, followingId),
        decoder: (json) => json == true,
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'follow_status_unknown',
        message: 'Follow status could not be loaded',
      ));
    }
  }
}
