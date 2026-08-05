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
    super.artistIds,
  });

  factory SpotifyTrackPreviewModel.fromJson(Map<String, dynamic> json) {
    final artistsNode = json['artistNames'] ?? json['artists'];
    final artistIdsNode = json['artistIds'] ?? json['artists'];
    final durationMs = json['durationMs'];
    return SpotifyTrackPreviewModel(
      id: json['spotifyTrackId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      previewUrl: json['previewUrl']?.toString(),
      durationSeconds: durationMs == null
          ? _durationSeconds(json['durationSeconds'])
          : _durationMilliseconds(durationMs),
      spotifyUrl: json['spotifyUrl']?.toString(),
      albumImageUrl: json['albumImageUrl']?.toString(),
      artistNames: _stringList(artistsNode),
      artistIds: _artistIdList(artistIdsNode),
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
      'artistIds': artistIds,
    };
  }

  static int? _durationSeconds(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final seconds = value.round();
    return seconds > 0 ? seconds : null;
  }

  static int? _durationMilliseconds(Object? value) {
    if (value is! num || !value.isFinite || value <= 0) return null;
    final seconds = (value / 1000).round();
    return seconds > 0 ? seconds : null;
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

  static List<String> _artistIdList(Object? value) {
    if (value is List) {
      return value
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item['id']?.toString() ??
                  item['spotifyArtistId']?.toString() ??
                  '';
            }
            return item.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }
}
