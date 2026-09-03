import '../../domain/entities/overthinking_post.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';
import '../../../profile/domain/entities/listener_visibility_mode.dart';

class OverthinkingPostModel extends OverthinkingPost {
  const OverthinkingPostModel({
    required super.id,
    required super.authorId,
    required super.authorUsername,
    required super.authorAvatarUrl,
    super.authorVisibilityMode,
    required super.anonymous,
    required super.canViewAuthor,
    required super.visibilityType,
    required super.title,
    required super.content,
    required super.spotifyTrackUrl,
    required super.spotifyArtistId,
    required super.spotifyTrackName,
    required super.spotifyArtistName,
    required super.spotifyAlbumImageUrl,
    required super.musicianTrackId,
    required super.bandTrackId,
    required super.artistId,
    required super.artistType,
    required super.likeCount,
    required super.commentCount,
    required super.likedByMe,
  });

  factory OverthinkingPostModel.fromJson(Map<String, dynamic> json) {
    return OverthinkingPostModel(
      id: json['id']?.toString() ?? '',
      authorId: json['authorId']?.toString(),
      authorUsername:
          json['authorUsername']?.toString() ??
          'Kimliğini açıklamak istemeyen yazar',
      authorAvatarUrl: _nullableText(json['authorAvatarUrl']),
      authorVisibilityMode: _authorVisibilityMode(json),
      anonymous: json['anonymous'] == true,
      canViewAuthor: json['canViewAuthor'] == true,
      visibilityType: json['visibilityType']?.toString() ?? 'VISIBLE',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      spotifyTrackUrl: _nullableText(json['spotifyTrackUrl']),
      spotifyArtistId: _nullableText(json['spotifyArtistId']),
      spotifyTrackName: _nullableText(json['spotifyTrackName']),
      spotifyArtistName: _nullableText(json['spotifyArtistName']),
      spotifyAlbumImageUrl: _nullableText(json['spotifyAlbumImageUrl']),
      musicianTrackId: _nullableText(json['musicianTrackId']),
      bandTrackId: _nullableText(json['bandTrackId']),
      artistId: _nullableText(json['artistId']),
      artistType: _nullableText(json['artistType']),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static ListenerVisibilityMode _authorVisibilityMode(
    Map<String, dynamic> json,
  ) {
    final authorId = _nullableText(json['authorId']);
    if (json['canViewAuthor'] != true || authorId == null) {
      return ListenerVisibilityMode.standard;
    }
    return parseContextualListenerVisibilityMode(json['authorVisibilityMode']);
  }
}
