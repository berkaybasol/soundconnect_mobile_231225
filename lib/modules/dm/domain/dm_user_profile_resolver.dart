import 'entities/dm_profile_target.dart';

abstract class DmUserProfileResolver {
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  });
}
