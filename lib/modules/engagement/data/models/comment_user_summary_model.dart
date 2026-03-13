import '../../domain/entities/comment_user_summary.dart';

class CommentUserSummaryModel extends CommentUserSummary {
  const CommentUserSummaryModel({
    required super.id,
    required super.username,
    required super.avatarUrl,
  });

  factory CommentUserSummaryModel.fromJson(Map<String, dynamic> json) {
    return CommentUserSummaryModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'unknown',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}
