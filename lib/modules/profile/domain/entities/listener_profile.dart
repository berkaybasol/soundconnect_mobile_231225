import 'listener_visibility_mode.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';

/// Listener self-view returned by the owner-only API.
///
/// Ghost mode keeps stable identity and avatar fields available while the
/// server omits showcase and social-graph data. The capability flags are the
/// source of truth for rendering actions; nullable fields must not be treated
/// as empty user data.
class ListenerProfile {
  final String id;
  final String userId;
  final String? username;
  final String? bio;
  final String? profilePictureMediaId;
  final String? profilePictureUrl;
  final int? followerCount;
  final int? followingCount;
  final ListenerVisibilityMode visibilityMode;
  final int version;
  final DateTime? visibilityChangedAt;
  final bool profileContentVisible;
  final bool profileContentEditable;
  final bool avatarEditable;
  final bool canReceiveFollowers;
  final bool visibilityChoiceCompleted;
  final List<SpotifyPlaylistPreview> playlists;

  const ListenerProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.bio,
    this.profilePictureMediaId,
    required this.profilePictureUrl,
    required this.followerCount,
    required this.followingCount,
    this.visibilityMode = ListenerVisibilityMode.standard,
    this.version = 0,
    this.visibilityChangedAt,
    bool? profileContentVisible,
    bool? profileContentEditable,
    this.avatarEditable = true,
    bool? canReceiveFollowers,
    bool visibilityChoiceCompleted = true,
    this.playlists = const <SpotifyPlaylistPreview>[],
  }) : visibilityChoiceCompleted = visibilityChoiceCompleted,
       profileContentVisible =
           profileContentVisible ??
           (visibilityChoiceCompleted &&
               visibilityMode == ListenerVisibilityMode.standard),
       profileContentEditable =
           profileContentEditable ??
           (visibilityChoiceCompleted &&
               visibilityMode == ListenerVisibilityMode.standard),
       canReceiveFollowers =
           canReceiveFollowers ??
           (visibilityChoiceCompleted &&
               visibilityMode == ListenerVisibilityMode.standard);

  bool get isGhost => visibilityMode == ListenerVisibilityMode.ghost;
}
