import '../../domain/entities/comment_item.dart';
import 'comment_user_summary_model.dart';
import 'comment_wire_date.dart';
import '../../domain/entities/comment_like_state.dart';

class CommentItemModel extends CommentItem {
  const CommentItemModel({
    required super.id,
    required super.user,
    super.anonymousAuthor,
    required super.text,
    required super.deleted,
    required super.parentCommentId,
    required super.replyCount,
    required super.createdAt,
    super.likeCount,
    super.likedByMe,
  });

  factory CommentItemModel.fromJson(Map<String, dynamic> json) {
    // Old responses may omit both fields during a coordinated rollout. A
    // partial/malformed new projection is not treated as a trustworthy zero.
    final hasLikes =
        json.containsKey('likeCount') || json.containsKey('likedByMe');
    final likes = hasLikes
        ? CommentLikeState.fromJson(json)
        : const CommentLikeState(likeCount: 0, likedByMe: false);
    return CommentItemModel(
      id: json['id']?.toString() ?? '',
      user: json['anonymousAuthor'] == true
          ? const CommentUserSummaryModel(
              id: '',
              username: 'Anonymous Author',
              avatarUrl: null,
            )
          : json['user'] is Map<String, dynamic>
          ? CommentUserSummaryModel.fromJson(
              json['user'] as Map<String, dynamic>,
            )
          : const CommentUserSummaryModel(
              id: '',
              username: 'unknown',
              avatarUrl: null,
            ),
      anonymousAuthor: json['anonymousAuthor'] == true,
      text: json['text']?.toString() ?? '',
      deleted: json['deleted'] == true,
      parentCommentId: json['parentCommentId']?.toString(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      createdAt: parseCommentWireDate(json['createdAt']),
      likeCount: json['deleted'] == true ? 0 : likes.likeCount,
      likedByMe: json['deleted'] != true && likes.likedByMe,
    );
  }
}
