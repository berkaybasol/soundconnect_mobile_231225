import 'comment_user_summary.dart';

class CommentItem {
  final String id;
  final CommentUserSummary user;
  final String text;
  final bool deleted;
  final String? parentCommentId;
  final int replyCount;
  final DateTime? createdAt;

  const CommentItem({
    required this.id,
    required this.user,
    required this.text,
    required this.deleted,
    required this.parentCommentId,
    required this.replyCount,
    required this.createdAt,
  });
}
