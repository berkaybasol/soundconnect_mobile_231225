import 'overthinking_post.dart';
import '../../../profile/domain/entities/listener_source_share_state.dart';

class OverthinkingProfileShareState extends ListenerSourceShareState {
  const OverthinkingProfileShareState({
    required String postId,
    required super.shareId,
    required super.publishedOnProfile,
    required super.note,
    required super.publishedAt,
    required super.canPublish,
  }) : super(sourceId: postId);

  String get postId => sourceId;
}

class OverthinkingProfileShare {
  const OverthinkingProfileShare({
    required this.shareId,
    required this.note,
    required this.publishedAt,
    required this.post,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  final String shareId;
  final String? note;
  final DateTime publishedAt;
  final OverthinkingPost post;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  OverthinkingProfileShare copyWithEngagement({
    required int likeCount,
    required int commentCount,
    required bool likedByMe,
  }) => OverthinkingProfileShare(
    shareId: shareId,
    note: note,
    publishedAt: publishedAt,
    post: post,
    likeCount: likeCount,
    commentCount: commentCount,
    likedByMe: likedByMe,
  );
}
