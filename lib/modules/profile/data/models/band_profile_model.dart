import '../../domain/entities/band_profile.dart';
import 'band_member_summary_model.dart';

class BandProfileModel extends BandProfile {
  const BandProfileModel({
    required super.id,
    required super.name,
    required super.description,
    required super.profilePictureUrl,
    required super.instagramUrl,
    required super.youtubeUrl,
    required super.soundCloudUrl,
    required super.spotifyEmbedUrl,
    required super.spotifyArtistId,
    required super.spotifyTrackIds,
    required super.members,
  });

  factory BandProfileModel.fromJson(Map<String, dynamic> json) {
    return BandProfileModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString(),
      profilePictureUrl:
          json['profilePictureUrl']?.toString() ??
          json['profilePicture']?.toString(),
      instagramUrl: json['instagramUrl']?.toString(),
      youtubeUrl: json['youtubeUrl']?.toString(),
      soundCloudUrl:
          json['soundCloudUrl']?.toString() ??
          json['soundcloudUrl']?.toString(),
      spotifyEmbedUrl: json['spotifyEmbedUrl']?.toString(),
      spotifyArtistId: json['spotifyArtistId']?.toString(),
      spotifyTrackIds: _stringList(json['spotifyTrackIds']),
      members: _members(json['members']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static List<BandMemberSummaryModel> _members(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(BandMemberSummaryModel.fromJson)
        .toList();
  }
}
