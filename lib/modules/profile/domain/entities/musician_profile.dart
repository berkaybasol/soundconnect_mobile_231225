class MusicianProfile {
  final String id;
  final String? stageName;
  final String? bio;
  final String? profilePicture;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? soundcloudUrl;
  final String? spotifyEmbedUrl;
  final String? spotifyArtistId;
  final List<String> instruments;
  final List<String> activeVenues;
  final List<String> bands;

  const MusicianProfile({
    required this.id,
    required this.stageName,
    required this.bio,
    required this.profilePicture,
    required this.instagramUrl,
    required this.youtubeUrl,
    required this.soundcloudUrl,
    required this.spotifyEmbedUrl,
    required this.spotifyArtistId,
    required this.instruments,
    required this.activeVenues,
    required this.bands,
  });
}
