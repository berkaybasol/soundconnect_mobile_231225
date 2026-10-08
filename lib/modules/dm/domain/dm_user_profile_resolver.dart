import 'entities/dm_profile_target.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/error/result.dart';

abstract interface class FollowUserProfileResolver {
  Future<Result<List<DmProfileTarget>>> resolveFreshForFollow({
    required String userId,
    required AuthSession session,
  });
}

abstract class DmUserProfileResolver {
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  });
}
