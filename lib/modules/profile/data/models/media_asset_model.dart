import '../../domain/entities/media_asset.dart';

class MediaAssetModel extends MediaAsset {
  const MediaAssetModel({
    required super.sourceUrl,
    required super.playbackUrl,
    required super.thumbnailUrl,
    required super.title,
    required super.durationSeconds,
  });

  factory MediaAssetModel.fromJson(Map<String, dynamic> json) {
    return MediaAssetModel(
      sourceUrl: json['sourceUrl']?.toString(),
      playbackUrl: json['playbackUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      title: json['title']?.toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }
}
