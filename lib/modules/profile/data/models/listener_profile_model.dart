import '../../domain/entities/listener_profile.dart';
import '../../domain/entities/listener_visibility_mode.dart';
import 'listener_profile_model_support.dart';

class ListenerProfileModel extends ListenerProfile {
  const ListenerProfileModel({
    required super.id,
    required super.userId,
    required super.username,
    required super.bio,
    required super.profilePictureMediaId,
    required super.profilePictureUrl,
    required super.followerCount,
    required super.followingCount,
    required super.visibilityMode,
    required super.version,
    required super.visibilityChangedAt,
    required super.profileContentVisible,
    required super.profileContentEditable,
    required super.avatarEditable,
    required super.canReceiveFollowers,
    required super.visibilityChoiceCompleted,
  });

  factory ListenerProfileModel.fromJson(Object? value) {
    final json = listenerProfileJsonObject(value);
    final visibilityMode = ListenerVisibilityMode.fromWire(
      json['visibilityMode'],
    );
    final bio = listenerOptionalString(json['bio'], 'bio');
    final followerCount = listenerOptionalNonNegativeInt(json, 'followerCount');
    final followingCount = listenerOptionalNonNegativeInt(
      json,
      'followingCount',
    );
    final profileContentVisible = listenerRequiredBool(
      json,
      'profileContentVisible',
    );
    final profileContentEditable = listenerRequiredBool(
      json,
      'profileContentEditable',
    );
    final avatarEditable = listenerRequiredBool(json, 'avatarEditable');
    final canReceiveFollowers = listenerRequiredBool(
      json,
      'canReceiveFollowers',
    );
    final visibilityChoiceCompleted = listenerRequiredBool(
      json,
      'visibilityChoiceCompleted',
    );

    _validateOwnerProjection(
      visibilityMode: visibilityMode,
      visibilityChoiceCompleted: visibilityChoiceCompleted,
      bio: bio,
      followerCount: followerCount,
      followingCount: followingCount,
      profileContentVisible: profileContentVisible,
      profileContentEditable: profileContentEditable,
      avatarEditable: avatarEditable,
      canReceiveFollowers: canReceiveFollowers,
    );

    return ListenerProfileModel(
      id: listenerRequiredString(json, 'id'),
      userId: listenerRequiredString(json, 'userId'),
      username: listenerRequiredString(json, 'username'),
      visibilityMode: visibilityMode,
      version: listenerRequiredNonNegativeInt(json, 'version'),
      visibilityChangedAt: listenerOptionalDateTime(
        json['visibilityChangedAt'],
        'visibilityChangedAt',
      ),
      bio: bio,
      profilePictureMediaId: listenerOptionalString(
        json['profilePictureMediaId'],
        'profilePictureMediaId',
      ),
      profilePictureUrl: listenerOptionalHttpUrl(
        json['profilePictureUrl'],
        'profilePictureUrl',
      ),
      followerCount: followerCount,
      followingCount: followingCount,
      profileContentVisible: profileContentVisible,
      profileContentEditable: profileContentEditable,
      avatarEditable: avatarEditable,
      canReceiveFollowers: canReceiveFollowers,
      visibilityChoiceCompleted: visibilityChoiceCompleted,
    );
  }

  static void _validateOwnerProjection({
    required ListenerVisibilityMode visibilityMode,
    required bool visibilityChoiceCompleted,
    required String? bio,
    required int? followerCount,
    required int? followingCount,
    required bool profileContentVisible,
    required bool profileContentEditable,
    required bool avatarEditable,
    required bool canReceiveFollowers,
  }) {
    if (!avatarEditable) {
      throw const FormatException('Listener avatar must remain editable');
    }
    // Until onboarding records an explicit choice, STANDARD is only a storage
    // default. Its owner projection must remain as restricted as ghost mode so
    // clients never mistake that default for an opted-in social profile.
    final restricted = visibilityMode.isGhost || !visibilityChoiceCompleted;
    if (restricted) {
      if (bio != null || followerCount != null || followingCount != null) {
        throw const FormatException(
          'Restricted listener owner projection must omit showcase and graph fields',
        );
      }
      if (profileContentVisible ||
          profileContentEditable ||
          canReceiveFollowers) {
        throw const FormatException(
          'Restricted listener owner projection has inconsistent capabilities',
        );
      }
      return;
    }

    if (followerCount == null || followingCount == null) {
      throw const FormatException(
        'Standard owner projection must include social counts',
      );
    }
    if (!profileContentVisible ||
        !profileContentEditable ||
        !canReceiveFollowers) {
      throw const FormatException(
        'Standard owner projection has inconsistent capabilities',
      );
    }
  }
}
