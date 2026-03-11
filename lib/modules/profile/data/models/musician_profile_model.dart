import '../../domain/entities/musician_profile.dart';
import '../../../spotify/data/models/spotify_track_preview_model.dart';

class MusicianProfileModel extends MusicianProfile {
  const MusicianProfileModel({
    required super.id,
    required super.userId,
    required super.stageName,
    required super.bio,
    required super.profilePicture,
    required super.instagramUrl,
    required super.youtubeUrl,
    required super.soundcloudUrl,
    required super.spotifyEmbedUrl,
    required super.spotifyArtistId,
    required super.spotifyTrackIds,
    required super.spotifyTracks,
    required super.instruments,
    required super.activeVenues,
    required super.bands,
  });

  factory MusicianProfileModel.fromJson(Map<String, dynamic> json) {
    final instruments = _stringList(json['instruments']);
    final activeVenues = _stringList(json['activeVenues']);
    final bands = _bandNames(json['bands']);

    return MusicianProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      stageName: json['stageName'] as String?,
      bio: json['bio'] as String?,
      profilePicture:
          json['profilePictureUrl'] as String? ?? json['profilePicture'] as String?,
      instagramUrl: json['instagramUrl'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      soundcloudUrl: json['soundcloudUrl'] as String?,
      spotifyEmbedUrl: json['spotifyEmbedUrl'] as String?,
      spotifyArtistId: json['spotifyArtistId'] as String?,
      spotifyTrackIds: _stringList(json['spotifyTrackIds']),
      spotifyTracks: _spotifyTracks(json['spotifyTracks']),
      instruments: instruments,
      activeVenues: activeVenues,
      bands: bands,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  static List<String> _bandNames(Object? value) {
    if (value is! List) return const [];
    final names = <String>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        final name = item['name']?.toString();
        if (name != null && name.isNotEmpty) {
          names.add(name);
        }
      } else if (item != null) {
        names.add(item.toString());
      }
    }
    return names;
  }

  static List<SpotifyTrackPreviewModel> _spotifyTracks(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(SpotifyTrackPreviewModel.fromJson)
        .toList();
  }
}
