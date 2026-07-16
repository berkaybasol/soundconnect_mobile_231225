class DmEndpoints {
  static const String _userBase = '/api/v1/user/dm';

  static const String conversationsMy = '$_userBase/conversations/my';
  static const String conversationBetween = '$_userBase/conversations/between';
  static const String messageSend = '$_userBase/messages';
  static const String unreadCount = '$_userBase/unread-count';

  static String conversationMessages(String conversationId) =>
      '$_userBase/messages/conversation/$conversationId';

  static String messageMarkRead(String messageId) =>
      '$_userBase/messages/$messageId/read';
}
