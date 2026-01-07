import '../../domain/entities/musician_profile.dart';

class MusicianProfileModel extends MusicianProfile {
  const MusicianProfileModel({
    required super.id,
    required super.stageName,
    required super.bio,
    required super.profilePicture,
    required super.instagramUrl,
    required super.youtubeUrl,
    required super.soundcloudUrl,
    required super.spotifyEmbedUrl,
    required super.spotifyArtistId,
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
      stageName: json['stageName'] as String?,
      bio: json['bio'] as String?,
      profilePicture: json['profilePicture'] as String?,
      instagramUrl: json['instagramUrl'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      soundcloudUrl: json['soundcloudUrl'] as String?,
      spotifyEmbedUrl: json['spotifyEmbedUrl'] as String?,
      spotifyArtistId: json['spotifyArtistId'] as String?,
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
}
