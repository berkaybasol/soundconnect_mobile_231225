class OverthinkingPost {
  final String id;
  final String? authorId;
  final String authorUsername;
  final String? authorAvatarUrl;
  final bool anonymous;
  final bool canViewAuthor;
  final String visibilityType;
  final String title;
  final String content;
  final String? spotifyTrackUrl;
  final String? spotifyArtistId;
  final String? spotifyTrackName;
  final String? spotifyArtistName;
  final String? spotifyAlbumImageUrl;
  final String? musicianTrackId;
  final String? bandTrackId;
  final String? artistId;
  final String? artistType;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  const OverthinkingPost({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.anonymous,
    required this.canViewAuthor,
    required this.visibilityType,
    required this.title,
    required this.content,
    required this.spotifyTrackUrl,
    required this.spotifyArtistId,
    required this.spotifyTrackName,
    required this.spotifyArtistName,
    required this.spotifyAlbumImageUrl,
    required this.musicianTrackId,
    required this.bandTrackId,
    required this.artistId,
    required this.artistType,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  OverthinkingPost copyWith({
    String? id,
    Object? authorId = _unset,
    String? authorUsername,
    Object? authorAvatarUrl = _unset,
    bool? anonymous,
    bool? canViewAuthor,
    String? visibilityType,
    String? title,
    String? content,
    Object? spotifyTrackUrl = _unset,
    Object? spotifyArtistId = _unset,
    Object? spotifyTrackName = _unset,
    Object? spotifyArtistName = _unset,
    Object? spotifyAlbumImageUrl = _unset,
    Object? musicianTrackId = _unset,
    Object? bandTrackId = _unset,
    Object? artistId = _unset,
    Object? artistType = _unset,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
  }) {
    return OverthinkingPost(
      id: id ?? this.id,
      authorId: identical(authorId, _unset)
          ? this.authorId
          : authorId as String?,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: identical(authorAvatarUrl, _unset)
          ? this.authorAvatarUrl
          : authorAvatarUrl as String?,
      anonymous: anonymous ?? this.anonymous,
      canViewAuthor: canViewAuthor ?? this.canViewAuthor,
      visibilityType: visibilityType ?? this.visibilityType,
      title: title ?? this.title,
      content: content ?? this.content,
      spotifyTrackUrl: identical(spotifyTrackUrl, _unset)
          ? this.spotifyTrackUrl
          : spotifyTrackUrl as String?,
      spotifyArtistId: identical(spotifyArtistId, _unset)
          ? this.spotifyArtistId
          : spotifyArtistId as String?,
      spotifyTrackName: identical(spotifyTrackName, _unset)
          ? this.spotifyTrackName
          : spotifyTrackName as String?,
      spotifyArtistName: identical(spotifyArtistName, _unset)
          ? this.spotifyArtistName
          : spotifyArtistName as String?,
      spotifyAlbumImageUrl: identical(spotifyAlbumImageUrl, _unset)
          ? this.spotifyAlbumImageUrl
          : spotifyAlbumImageUrl as String?,
      musicianTrackId: identical(musicianTrackId, _unset)
          ? this.musicianTrackId
          : musicianTrackId as String?,
      bandTrackId: identical(bandTrackId, _unset)
          ? this.bandTrackId
          : bandTrackId as String?,
      artistId: identical(artistId, _unset)
          ? this.artistId
          : artistId as String?,
      artistType: identical(artistType, _unset)
          ? this.artistType
          : artistType as String?,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

const Object _unset = Object();
