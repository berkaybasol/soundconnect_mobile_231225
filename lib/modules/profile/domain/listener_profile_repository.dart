import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import 'entities/listener_profile.dart';
import 'entities/listener_public_profile.dart';
import 'entities/listener_visibility_mode.dart';
import '../../spotify/domain/spotify_playlist_uri.dart';

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

  Future<Result<ListenerProfile>> replacePlaylists(
    ListenerPlaylistsReplaceRequest request,
  ) async {
    return const Result.failure(
      AppError(
        code: 'listener_playlists_update_unsupported',
        message: 'Çalma listeleri güncellenemiyor.',
      ),
    );
  }
}

class ListenerPlaylistsReplaceRequest {
  final List<String> spotifyUrls;
  final int expectedVersion;

  const ListenerPlaylistsReplaceRequest({
    required this.spotifyUrls,
    required this.expectedVersion,
  });

  Map<String, dynamic>? toValidatedJson() {
    if (expectedVersion < 0 || spotifyUrls.length > 4) return null;
    final normalized = <String>[];
    final ids = <String>{};
    for (final rawUrl in spotifyUrls) {
      final url = normalizeSpotifyPlaylistUrl(rawUrl);
      final id = spotifyPlaylistIdFromUrl(url);
      if (url == null || id == null || !ids.add(id)) return null;
      normalized.add(url);
    }
    return <String, dynamic>{
      'spotifyUrls': List<String>.unmodifiable(normalized),
      'expectedVersion': expectedVersion,
    };
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
