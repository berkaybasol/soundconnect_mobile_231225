class TableGroupEndpoints {
  static const String base = '/api/v1/table-groups';
  static const String active = '$base/active';

  static String detail(String tableGroupId) => '$base/$tableGroupId';
  static String join(String tableGroupId) => '$base/$tableGroupId/join';
  static String approve(String tableGroupId, String participantId) =>
      '$base/$tableGroupId/approve/$participantId';
  static String reject(String tableGroupId, String participantId) =>
      '$base/$tableGroupId/reject/$participantId';
  static String leave(String tableGroupId) => '$base/$tableGroupId/leave';
  static String kick(String tableGroupId, String participantId) =>
      '$base/$tableGroupId/kick/$participantId';
  static String cancel(String tableGroupId) => '$base/$tableGroupId/cancel';

  static String chatBase(String tableGroupId) => '$base/$tableGroupId/chat';
  static String chatMessages(String tableGroupId) =>
      '${chatBase(tableGroupId)}/messages';
  static String chatUnreadBadge(String tableGroupId) =>
      '${chatBase(tableGroupId)}/unread-badge';

  static String create() => base;
}
