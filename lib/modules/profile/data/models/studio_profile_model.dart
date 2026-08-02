import '../../domain/entities/studio_profile.dart';
import '../../../spotify/data/models/spotify_track_preview_model.dart';

class StudioProfileModel extends StudioProfile {
  const StudioProfileModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.description,
    required super.profilePictureMediaId,
    required super.profilePictureUrl,
    required super.address,
    required super.phone,
    required super.website,
    required super.facilities,
    required super.instagramUrl,
    required super.youtubeUrl,
    required super.timeZone,
    required super.version,
    required super.spotifyTrackIds,
    required super.spotifyTracks,
    required super.activeRoomCount,
    required super.backlineUnitCount,
    super.cityId,
    super.cityName,
    super.districtId,
    super.districtName,
    super.neighborhoodId,
    super.neighborhoodName,
  });

  factory StudioProfileModel.fromJson(Map<String, dynamic> json) {
    final rawFacilities = json['facilities'];
    return StudioProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: _stringOrNull(json['name']),
      description: _stringOrNull(json['description']),
      profilePictureMediaId: _stringOrNull(json['profilePictureMediaId']),
      profilePictureUrl: _stringOrNull(json['profilePictureUrl']),
      address: _stringOrNull(json['address'] ?? json['adress']),
      cityId: _stringOrNull(json['cityId']),
      cityName: _stringOrNull(json['cityName']),
      districtId: _stringOrNull(json['districtId']),
      districtName: _stringOrNull(json['districtName']),
      neighborhoodId: _stringOrNull(json['neighborhoodId']),
      neighborhoodName: _stringOrNull(json['neighborhoodName']),
      phone: _stringOrNull(json['phone']),
      website: _stringOrNull(json['website']),
      facilities: rawFacilities is List
          ? rawFacilities
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      instagramUrl: _stringOrNull(json['instagramUrl']),
      youtubeUrl: _stringOrNull(json['youtubeUrl']),
      timeZone: _stringOrNull(json['timeZone']) ?? 'Europe/Istanbul',
      version: (json['version'] as num?)?.toInt() ?? 0,
      spotifyTrackIds: _stringList(json['spotifyTrackIds']),
      spotifyTracks: _spotifyTracks(json['spotifyTracks']),
      activeRoomCount: (json['activeRoomCount'] as num?)?.toInt() ?? 0,
      backlineUnitCount: (json['backlineUnitCount'] as num?)?.toInt() ?? 0,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<SpotifyTrackPreviewModel> _spotifyTracks(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => SpotifyTrackPreviewModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((track) => track.id.isNotEmpty)
        .toList(growable: false);
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
