import '../../../core/error/result.dart';

abstract class BandFollowRepository {
  Future<Result<int>> getFollowersCount(String bandId);
}
