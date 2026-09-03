import 'listener_visibility_mode.dart';

/// Public-safe listener projection.
///
/// Showcase and graph fields are nullable because the server deliberately
/// omits them for ghost profiles. Callers must use [restricted]/[canFollow]
/// rather than interpreting a missing count as zero.
class ListenerPublicProfile {
  final String id;
  final String userId;
  final String username;
  final ListenerVisibilityMode visibilityMode;
  final String? bio;
  final String? profilePictureMediaId;
  final String? profilePictureUrl;
  final int? followerCount;
  final int? followingCount;
  final bool restricted;
  final bool canFollow;
  final bool canMessage;

  const ListenerPublicProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.visibilityMode,
    required this.bio,
    required this.profilePictureMediaId,
    required this.profilePictureUrl,
    required this.followerCount,
    required this.followingCount,
    required this.restricted,
    required this.canFollow,
    required this.canMessage,
  });

  bool get isGhost => visibilityMode == ListenerVisibilityMode.ghost;
}
