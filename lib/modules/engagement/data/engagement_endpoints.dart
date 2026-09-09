class EngagementEndpoints {
  static const String _likesBase = '/api/v1/likes';
  static String commentLike(String commentId) =>
      '$_likesBase/COMMENT/${Uri.encodeComponent(commentId)}';
  static String commentLikeState(String commentId) =>
      '${commentLike(commentId)}/state';
  static const String _commentsBase = '/api/v1/comments';

  static String like(String targetType, String targetId) =>
      '$_likesBase/${Uri.encodeComponent(targetType)}/${Uri.encodeComponent(targetId)}';

  static String unlike(String targetType, String targetId) =>
      like(targetType, targetId);

  static String likeCount(String targetType, String targetId) =>
      '${like(targetType, targetId)}/count';

  static String isLiked(String targetType, String targetId) =>
      '${like(targetType, targetId)}/is-liked';

  static String createComment(String targetType, String targetId) =>
      '$_commentsBase/${Uri.encodeComponent(targetType)}/${Uri.encodeComponent(targetId)}';

  static String listComments(String targetType, String targetId) =>
      createComment(targetType, targetId);

  static String deleteComment(String commentId) =>
      '$_commentsBase/${Uri.encodeComponent(commentId)}';

  static String listReplies(String commentId) =>
      '$_commentsBase/replies/${Uri.encodeComponent(commentId)}';
}
