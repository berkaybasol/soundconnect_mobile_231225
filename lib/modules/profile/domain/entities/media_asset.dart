class MediaAsset {
  final String? sourceUrl;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final String? title;
  final int? durationSeconds;

  const MediaAsset({
    required this.sourceUrl,
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.durationSeconds,
  });
}
