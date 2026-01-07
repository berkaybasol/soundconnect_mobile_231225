import '../../../core/error/result.dart';
import '../data/models/musician_profile_save_request.dart';
import 'entities/musician_profile.dart';

abstract class MusicianProfileRepository {
  Future<Result<MusicianProfile>> getMyProfile();
  Future<Result<MusicianProfile>> updateMyProfile(
    MusicianProfileSaveRequest request,
  );
}
