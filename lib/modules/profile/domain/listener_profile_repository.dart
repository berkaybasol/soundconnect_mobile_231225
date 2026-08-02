import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import 'entities/listener_profile.dart';

abstract class ListenerProfileRepository {
  Future<Result<ListenerProfile>> getMyProfile();

  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async {
    return const Result.failure(
      AppError(
        code: 'listener_profile_update_unsupported',
        message: 'Listener profili güncellenemiyor.',
      ),
    );
  }
}

class ListenerProfileSaveRequest {
  final String? description;
  final String? profilePictureMediaId;

  const ListenerProfileSaveRequest({
    this.description,
    this.profilePictureMediaId,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'profilePictureMediaId': profilePictureMediaId,
    }..removeWhere((_, value) => value == null);
  }
}
