class NotificationEndpoints {
  static const String _userBase = '/api/v1/user/notifications';

  static const String list = _userBase;
  static const String recent = '$_userBase/recent';
  static const String unreadCount = '$_userBase/unread-count';
  static const String markAllRead = '$_userBase/read-all';

  static String markRead(String notificationId) =>
      '$_userBase/$notificationId/read';

  static String delete(String notificationId) => '$_userBase/$notificationId';
}
