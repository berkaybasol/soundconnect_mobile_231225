import '../../domain/entities/spotify_track_preview.dart';

class SpotifyTrackPreviewModel extends SpotifyTrackPreview {
  const SpotifyTrackPreviewModel({
    required super.id,
    required super.name,
    required super.previewUrl,
    required super.durationSeconds,
    required super.spotifyUrl,
    required super.albumImageUrl,
    required super.artistNames,
  });

  factory SpotifyTrackPreviewModel.fromJson(Map<String, dynamic> json) {
    final artistsNode = json['artistNames'] ?? json['artists'];
    return SpotifyTrackPreviewModel(
      id: json['spotifyTrackId']?.toString() ??
          json['id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      previewUrl: json['previewUrl']?.toString(),
      durationSeconds: _durationSeconds(
        json['durationMs'] ?? json['durationSeconds'],
      ),
      spotifyUrl: json['spotifyUrl']?.toString(),
      albumImageUrl: json['albumImageUrl']?.toString(),
      artistNames: _stringList(artistsNode),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spotifyTrackId': id,
      'name': name,
      'durationMs': durationSeconds != null ? durationSeconds! * 1000 : null,
      'explicit': false,
      'previewUrl': previewUrl,
      'spotifyUrl': spotifyUrl,
      'albumName': null,
      'albumImageUrl': albumImageUrl,
      'artistNames': artistNames,
    };
  }

  static int? _durationSeconds(Object? value) {
    if (value is num) {
      // if value already in seconds (small number), keep it
      final seconds = value > 1000 ? (value / 1000).round() : value.round();
      return seconds > 0 ? seconds : null;
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item['name']?.toString() ?? '';
            }
            return item.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }
}
