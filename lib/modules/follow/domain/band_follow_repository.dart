import '../../../core/error/result.dart';

abstract class BandFollowRepository {
  Future<Result<int>> getFollowersCount(String bandId);
  Future<Result<void>> followBand(String bandId);
  Future<Result<void>> unfollowBand(String bandId);
  Future<Result<bool>> isFollowingBand(String bandId);
}
