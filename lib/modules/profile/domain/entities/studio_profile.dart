import '../../../spotify/domain/entities/spotify_track_preview.dart';

class StudioProfile {
  final String id;
  final String userId;
  final String? name;
  final String? description;
  final String? profilePictureMediaId;
  final String? profilePictureUrl;
  final String? address;
  final String? cityId;
  final String? cityName;
  final String? districtId;
  final String? districtName;
  final String? neighborhoodId;
  final String? neighborhoodName;
  final String? phone;
  final String? website;
  final List<String> facilities;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String timeZone;
  final int version;
  final List<String> spotifyTrackIds;
  final List<SpotifyTrackPreview> spotifyTracks;
  final int activeRoomCount;
  final int backlineUnitCount;

  const StudioProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.profilePictureMediaId,
    required this.profilePictureUrl,
    required this.address,
    required this.phone,
    required this.website,
    required this.facilities,
    required this.instagramUrl,
    required this.youtubeUrl,
    required this.timeZone,
    required this.version,
    required this.spotifyTrackIds,
    required this.spotifyTracks,
    required this.activeRoomCount,
    required this.backlineUnitCount,
    this.cityId,
    this.cityName,
    this.districtId,
    this.districtName,
    this.neighborhoodId,
    this.neighborhoodName,
  });

  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'Studio' : value;
  }
}
