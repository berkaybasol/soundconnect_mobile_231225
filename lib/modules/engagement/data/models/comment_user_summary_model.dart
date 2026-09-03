import '../../domain/entities/comment_user_summary.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';

class CommentUserSummaryModel extends CommentUserSummary {
  const CommentUserSummaryModel({
    required super.id,
    required super.username,
    required super.avatarUrl,
    super.visibilityMode,
  });

  factory CommentUserSummaryModel.fromJson(Map<String, dynamic> json) {
    return CommentUserSummaryModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'unknown',
      avatarUrl:
          json['avatarUrl']?.toString() ??
          json['profilePictureUrl']?.toString() ??
          json['profileImageUrl']?.toString(),
      visibilityMode: parseContextualListenerVisibilityMode(
        json['visibilityMode'],
      ),
    );
  }
}
