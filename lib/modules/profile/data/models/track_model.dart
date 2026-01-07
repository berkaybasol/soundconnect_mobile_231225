import '../../domain/entities/track.dart';

class TrackModel extends Track {
  const TrackModel({
    required super.id,
    required super.title,
    required super.playbackUrl,
    required super.durationSeconds,
    required super.bpm,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      playbackUrl: json['playbackUrl']?.toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      bpm: (json['bpm'] as num?)?.toInt(),
    );
  }
}
