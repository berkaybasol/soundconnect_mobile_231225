import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import 'entities/listener_profile.dart';
import 'entities/listener_public_profile.dart';
import 'entities/listener_visibility_mode.dart';

abstract class ListenerProfileRepository {
  const ListenerProfileRepository();

  Future<Result<ListenerProfile>> getMyProfile();

  Future<Result<ListenerPublicProfile>> getPublicProfile(
    String profileId,
  ) async {
    return const Result.failure(
      AppError(
        code: 'listener_public_profile_unsupported',
        message: 'Dinleyici profili görüntülenemiyor.',
      ),
    );
  }

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

  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    return const Result.failure(
      AppError(
        code: 'listener_visibility_update_unsupported',
        message: 'Profil görünürlüğü güncellenemiyor.',
      ),
    );
  }

  Future<Result<ListenerProfile>> updateAvatar(
    ListenerAvatarUpdateRequest request,
  ) async {
    return const Result.failure(
      AppError(
        code: 'listener_avatar_update_unsupported',
        message: 'Profil fotoğrafı güncellenemiyor.',
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

class ListenerVisibilityUpdateRequest {
  final ListenerVisibilityMode visibilityMode;
  final int expectedVersion;

  const ListenerVisibilityUpdateRequest({
    required this.visibilityMode,
    required this.expectedVersion,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'visibilityMode': visibilityMode.wireValue,
    'expectedVersion': expectedVersion,
  };
}

/// Avatar command with intentional nullable payload semantics.
///
/// [profilePictureMediaId] is always serialized. Passing `null` means remove
/// the avatar; it must never be dropped from the JSON object.
class ListenerAvatarUpdateRequest {
  final String? profilePictureMediaId;
  final int expectedVersion;

  const ListenerAvatarUpdateRequest({
    required this.profilePictureMediaId,
    required this.expectedVersion,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profilePictureMediaId': profilePictureMediaId,
    'expectedVersion': expectedVersion,
  };
}
