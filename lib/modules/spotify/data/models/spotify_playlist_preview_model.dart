import '../../domain/entities/spotify_playlist_preview.dart';
import '../../domain/spotify_playlist_uri.dart';

class SpotifyPlaylistPreviewModel extends SpotifyPlaylistPreview {
  const SpotifyPlaylistPreviewModel({
    required super.id,
    required super.spotifyPlaylistId,
    required super.title,
    required super.coverImageUrl,
    required super.spotifyUrl,
    required super.position,
  });

  factory SpotifyPlaylistPreviewModel.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Spotify playlist must be a JSON object');
    }
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('Spotify playlist keys must be strings');
    }
    final json = Map<String, dynamic>.from(value);
    final id = _requiredString(json['id'], 'id', maxLength: 100);
    final spotifyPlaylistId = _requiredString(
      json['spotifyPlaylistId'],
      'spotifyPlaylistId',
      maxLength: 64,
    );
    final title = _requiredString(json['title'], 'title', maxLength: 255);
    final rawSpotifyUrl = _requiredString(
      json['spotifyUrl'],
      'spotifyUrl',
      maxLength: 512,
    );
    final spotifyUrl = normalizeSpotifyPlaylistUrl(rawSpotifyUrl);
    if (spotifyUrl == null ||
        spotifyPlaylistIdFromUrl(spotifyUrl) != spotifyPlaylistId) {
      throw const FormatException('spotifyUrl must identify spotifyPlaylistId');
    }
    final coverImageUrl = _requiredSpotifyArtworkUrl(
      json['coverImageUrl'],
      'coverImageUrl',
    );
    final position = json['position'];
    if (position is! int || position < 0 || position > 3) {
      throw const FormatException('position must be between 0 and 3');
    }

    return SpotifyPlaylistPreviewModel(
      id: id,
      spotifyPlaylistId: spotifyPlaylistId,
      title: title,
      coverImageUrl: coverImageUrl,
      spotifyUrl: spotifyUrl,
      position: position,
    );
  }
}

List<SpotifyPlaylistPreview> spotifyPlaylistPreviewsFromJson(Object? value) {
  if (value == null) return const <SpotifyPlaylistPreview>[];
  if (value is! List) {
    throw const FormatException('playlists must be a JSON array');
  }
  if (value.length > 4) {
    throw const FormatException('playlists cannot contain more than 4 items');
  }

  final items = <SpotifyPlaylistPreview>[];
  final ids = <String>{};
  final spotifyIds = <String>{};
  for (var index = 0; index < value.length; index++) {
    final item = SpotifyPlaylistPreviewModel.fromJson(value[index]);
    if (item.position != index ||
        !ids.add(item.id) ||
        !spotifyIds.add(item.spotifyPlaylistId)) {
      throw const FormatException(
        'playlists must have unique ids and contiguous positions',
      );
    }
    items.add(item);
  }
  return List<SpotifyPlaylistPreview>.unmodifiable(items);
}

String _requiredString(Object? value, String field, {required int maxLength}) {
  if (value is! String) throw FormatException('$field must be a string');
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxLength) {
    throw FormatException('$field has an invalid length');
  }
  return normalized;
}

String _requiredSpotifyArtworkUrl(Object? value, String field) {
  final raw = _requiredString(value, field, maxLength: 2048);
  final uri = Uri.tryParse(raw);
  final host = uri?.host.toLowerCase();
  final trustedSpotifyHost =
      host == 'scdn.co' ||
      (host?.endsWith('.scdn.co') ?? false) ||
      host == 'spotifycdn.com' ||
      (host?.endsWith('.spotifycdn.com') ?? false);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !trustedSpotifyHost ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      uri.path.isEmpty ||
      uri.hasFragment) {
    throw FormatException('$field must be a trusted Spotify artwork URL');
  }
  return uri.toString();
}
