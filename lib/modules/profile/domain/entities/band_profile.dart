import 'band_member_summary.dart';

class BandProfile {
  final String id;
  final String name;
  final String? description;
  final String? profilePictureUrl;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? soundCloudUrl;
  final String? spotifyEmbedUrl;
  final String? spotifyArtistId;
  final List<String> spotifyTrackIds;
  final List<BandMemberSummary> members;

  const BandProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.profilePictureUrl,
    required this.instagramUrl,
    required this.youtubeUrl,
    required this.soundCloudUrl,
    required this.spotifyEmbedUrl,
    required this.spotifyArtistId,
    required this.spotifyTrackIds,
    required this.members,
  });
}
