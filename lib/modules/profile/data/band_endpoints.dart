class BandEndpoints {
  static const String userBase = '/api/v1/user/bands';
  static const String create = '$userBase/create';
  static const String myBands = '$userBase/my';

  static String byId(String bandId) => '$userBase/$bandId';
  static String invite(String bandId, String invitedUserId, {String? message}) {
    final query = <String, String>{'invitedUserId': invitedUserId};
    if (message != null && message.trim().isNotEmpty) {
      query['message'] = message.trim();
    }
    final uri = Uri(path: '$userBase/$bandId/invite', queryParameters: query);
    return uri.toString();
  }

  static String removeMember(String bandId, String userId) =>
      '$userBase/$bandId/remove/$userId';
  static String leave(String bandId) => '$userBase/$bandId/leave';
}
