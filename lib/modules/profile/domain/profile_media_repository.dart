import '../../../core/error/result.dart';
import 'entities/profile_media.dart';

abstract class ProfileMediaRepository {
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  });
}
