class Track {
  final String id;
  final String mediaAssetId;
  final String title;
  final String? playbackUrl;
  final int? durationSeconds;
  final int? bpm;

  const Track({
    required this.id,
    required this.mediaAssetId,
    required this.title,
    required this.playbackUrl,
    required this.durationSeconds,
    required this.bpm,
  });
}
