final RegExp _spotifyPlaylistIdPattern = RegExp(r'^[A-Za-z0-9]{22}$');
final RegExp _spotifyPlaylistPathPattern = RegExp(
  r'^/(?:intl-[A-Za-z]{2}/)?playlist/([A-Za-z0-9]{22})/?$',
  caseSensitive: false,
);

/// Accepts Spotify's canonical web links, including localized `/intl-*` links,
/// and returns the query-free canonical URL used by the API contract.
String? normalizeSpotifyPlaylistUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || value.length > 2048) return null;

  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.toLowerCase() != 'open.spotify.com' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }

  final schemeSeparator = value.indexOf('://');
  final rawPathStart = value.indexOf('/', schemeSeparator + 3);
  if (schemeSeparator < 0 || rawPathStart < 0) return null;
  var rawPathEnd = value.length;
  for (final delimiter in const <String>['?', '#']) {
    final index = value.indexOf(delimiter, rawPathStart);
    if (index >= 0 && index < rawPathEnd) rawPathEnd = index;
  }
  final rawPath = value.substring(rawPathStart, rawPathEnd);

  // Match the encoded path itself so doubled separators and percent-encoded
  // aliases cannot pass the client and then fail the stricter backend parser.
  final pathMatch = _spotifyPlaylistPathPattern.firstMatch(rawPath);
  if (rawPath.contains('%') || pathMatch == null) {
    return null;
  }

  final playlistId = pathMatch.group(1)!;
  if (!_spotifyPlaylistIdPattern.hasMatch(playlistId)) return null;
  return Uri.https('open.spotify.com', '/playlist/$playlistId').toString();
}

Uri? spotifyPlaylistUri(String? raw) {
  final normalized = normalizeSpotifyPlaylistUrl(raw);
  return normalized == null ? null : Uri.parse(normalized);
}

String? spotifyPlaylistIdFromUrl(String? raw) {
  final uri = spotifyPlaylistUri(raw);
  return uri?.pathSegments.last;
}
