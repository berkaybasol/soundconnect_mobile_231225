/// Server-verified Spotify playlist metadata displayed on listener profiles.
///
/// The title and artwork are authoritative snapshots resolved by the backend;
/// clients only submit Spotify playlist links when editing the collection.
class SpotifyPlaylistPreview {
  final String id;
  final String spotifyPlaylistId;
  final String title;
  final String coverImageUrl;
  final String spotifyUrl;
  final int position;

  const SpotifyPlaylistPreview({
    required this.id,
    required this.spotifyPlaylistId,
    required this.title,
    required this.coverImageUrl,
    required this.spotifyUrl,
    required this.position,
  });
}
