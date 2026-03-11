import '../../../core/error/result.dart';

abstract class FollowRepository {
  Future<Result<int>> getFollowersCount(String userId);
  Future<Result<int>> getFollowingCount(String userId);
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  });
  Future<Result<void>> unfollow({
    required String followerId,
    required String followingId,
  });
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  });
}
