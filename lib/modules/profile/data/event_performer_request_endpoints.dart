class EventPerformerRequestEndpoints {
  static const String base = '/api/v1/event-performer-requests';

  static const String mine = '$base/mine';

  static String accept(String requestId) =>
      '$base/${Uri.encodeComponent(requestId)}/accept';

  static String reject(String requestId) =>
      '$base/${Uri.encodeComponent(requestId)}/reject';

  static String reconsider(String requestId) =>
      '$base/${Uri.encodeComponent(requestId)}/reconsider';
}
