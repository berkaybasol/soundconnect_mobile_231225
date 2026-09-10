import '../../../overthinking/domain/entities/overthinking_post.dart';
import '../../../overthinking/domain/trusted_spotify_artwork.dart';

/// Only publicly exportable content. A private identity grant is never carried
/// into an image that will be viewed outside SoundConnect.
class OverthinkingShareData {
  const OverthinkingShareData._({
    required this.postId,
    required this.title,
    required this.content,
    required this.authorLabel,
    required this.authorAvatarUrl,
    required this.albumImageUrl,
    required this.trackName,
    required this.artistName,
    required this.anonymous,
    required this.hasMusic,
  });

  factory OverthinkingShareData.fromPost(OverthinkingPost post) {
    final name = _text(
      post.authorUsername,
    ).replaceFirst(RegExp(r'^(?:@\s*)+'), '').trim();
    final hidden =
        post.anonymous ||
        post.visibilityType.trim().toUpperCase() == 'ANONYMOUS' ||
        !post.hasVisibleAuthor ||
        name.isEmpty;
    final track = _text(post.spotifyTrackName);
    final artist = _text(post.spotifyArtistName);
    return OverthinkingShareData._(
      postId: post.id.trim(),
      title: _text(post.title),
      content: _text(post.content),
      authorLabel: hidden ? 'Anonim yazar' : '@$name',
      authorAvatarUrl: hidden ? null : _imageUrl(post.authorAvatarUrl),
      albumImageUrl: trustedSpotifyArtworkUrl(post.spotifyAlbumImageUrl),
      trackName: track,
      artistName: artist,
      anonymous: hidden,
      hasMusic:
          track.isNotEmpty ||
          artist.isNotEmpty ||
          post.spotifyTrackUrl?.trim().isNotEmpty == true ||
          post.musicianTrackId?.trim().isNotEmpty == true ||
          post.bandTrackId?.trim().isNotEmpty == true,
    );
  }

  final String postId;
  final String title;
  final String content;
  final String authorLabel;
  final String? authorAvatarUrl;
  final String? albumImageUrl;
  final String trackName;
  final String artistName;
  final bool anonymous;
  final bool hasMusic;

  String get accessibilityDescription => [
    'SoundConnect · Overthinking',
    authorLabel,
    title,
    content,
    if (hasMusic)
      [trackName, artistName].where((s) => s.isNotEmpty).join(' · '),
  ].where((s) => s.isNotEmpty).join('\n');

  /// Fresh validation may update counters without changing the approved image.
  bool matches(OverthinkingShareData other) =>
      postId == other.postId &&
      title == other.title &&
      content == other.content &&
      authorLabel == other.authorLabel &&
      authorAvatarUrl == other.authorAvatarUrl &&
      albumImageUrl == other.albumImageUrl &&
      trackName == other.trackName &&
      artistName == other.artistName &&
      anonymous == other.anonymous &&
      hasMusic == other.hasMusic;

  static String _text(String? value) => (value ?? '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .trim();

  static String? _imageUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }
}
