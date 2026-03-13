import '../../domain/entities/comment_item.dart';
import 'comment_user_summary_model.dart';

class CommentItemModel extends CommentItem {
  const CommentItemModel({
    required super.id,
    required super.user,
    required super.text,
    required super.deleted,
    required super.parentCommentId,
    required super.replyCount,
    required super.createdAt,
  });

  factory CommentItemModel.fromJson(Map<String, dynamic> json) {
    return CommentItemModel(
      id: json['id']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic>
          ? CommentUserSummaryModel.fromJson(
              json['user'] as Map<String, dynamic>,
            )
          : const CommentUserSummaryModel(
              id: '',
              username: 'unknown',
              avatarUrl: null,
            ),
      text: json['text']?.toString() ?? '',
      deleted: json['deleted'] == true,
      parentCommentId: json['parentCommentId']?.toString(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
