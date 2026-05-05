class SpotifyTrackPreview {
  final String id;
  final String name;
  final String? previewUrl;
  final int? durationSeconds;
  final String? spotifyUrl;
  final String? albumImageUrl;
  final List<String> artistNames;
  final List<String> artistIds;

  const SpotifyTrackPreview({
    required this.id,
    required this.name,
    required this.previewUrl,
    required this.durationSeconds,
    required this.spotifyUrl,
    required this.albumImageUrl,
    required this.artistNames,
    this.artistIds = const [],
  });
}
