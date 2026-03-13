class EngagementEndpoints {
  static const String _likesBase = '/api/v1/likes';
  static const String _commentsBase = '/api/v1/comments';

  static String like(String targetType, String targetId) =>
      '$_likesBase/$targetType/$targetId';

  static String unlike(String targetType, String targetId) =>
      '$_likesBase/$targetType/$targetId';

  static String likeCount(String targetType, String targetId) =>
      '$_likesBase/$targetType/$targetId/count';

  static String isLiked(String targetType, String targetId) =>
      '$_likesBase/$targetType/$targetId/is-liked';

  static String createComment(String targetType, String targetId) =>
      '$_commentsBase/$targetType/$targetId';

  static String listComments(String targetType, String targetId) =>
      '$_commentsBase/$targetType/$targetId';

  static String deleteComment(String commentId) => '$_commentsBase/$commentId';

  static String listReplies(String commentId) =>
      '$_commentsBase/replies/$commentId';
}
