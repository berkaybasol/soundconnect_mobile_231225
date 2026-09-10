/// Track artwork is fetched by the device, so stored/user supplied metadata
/// must never select an arbitrary host (including in older server responses).
String? trustedSpotifyArtworkUrl(String? value) {
  final raw = value?.trim() ?? '';
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'i.scdn.co' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/image/[A-Za-z0-9]+$').hasMatch(uri.path)) {
    return null;
  }
  return uri.toString();
}
