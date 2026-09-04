import '../../domain/entities/listener_public_profile.dart';
import '../../domain/entities/listener_visibility_mode.dart';
import '../../../spotify/data/models/spotify_playlist_preview_model.dart';
import 'listener_profile_model_support.dart';

class ListenerPublicProfileModel extends ListenerPublicProfile {
  const ListenerPublicProfileModel({
    required super.id,
    required super.userId,
    required super.username,
    required super.visibilityMode,
    required super.bio,
    required super.profilePictureMediaId,
    required super.profilePictureUrl,
    required super.followerCount,
    required super.followingCount,
    required super.restricted,
    required super.canFollow,
    required super.canMessage,
    required super.playlists,
  });

  factory ListenerPublicProfileModel.fromJson(Object? value) {
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
    final restricted = listenerRequiredBool(json, 'restricted');
    final canFollow = listenerRequiredBool(json, 'canFollow');
    final canMessage = listenerRequiredBool(json, 'canMessage');
    final playlists = spotifyPlaylistPreviewsFromJson(json['playlists']);

    _validatePublicProjection(
      visibilityMode: visibilityMode,
      bio: bio,
      followerCount: followerCount,
      followingCount: followingCount,
      restricted: restricted,
      canFollow: canFollow,
      canMessage: canMessage,
      playlists: playlists,
    );

    return ListenerPublicProfileModel(
      id: listenerRequiredString(json, 'id'),
      userId: listenerRequiredString(json, 'userId'),
      username: listenerRequiredString(json, 'username'),
      visibilityMode: visibilityMode,
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
      restricted: restricted,
      canFollow: canFollow,
      canMessage: canMessage,
      playlists: playlists,
    );
  }

  static void _validatePublicProjection({
    required ListenerVisibilityMode visibilityMode,
    required String? bio,
    required int? followerCount,
    required int? followingCount,
    required bool restricted,
    required bool canFollow,
    required bool canMessage,
    required List<Object> playlists,
  }) {
    if (!canMessage) {
      throw const FormatException('Listener profiles must remain messageable');
    }
    if (visibilityMode.isGhost) {
      if (bio != null || followerCount != null || followingCount != null) {
        throw const FormatException(
          'Ghost public projection must omit showcase and graph fields',
        );
      }
      if (!restricted || canFollow) {
        throw const FormatException(
          'Ghost public projection has inconsistent capabilities',
        );
      }
      if (playlists.isNotEmpty) {
        throw const FormatException(
          'Ghost public projection must omit playlists',
        );
      }
      return;
    }

    if (followerCount == null || followingCount == null) {
      throw const FormatException(
        'Standard public projection must include social counts',
      );
    }
    if (restricted || !canFollow) {
      throw const FormatException(
        'Standard public projection has inconsistent capabilities',
      );
    }
  }
}
