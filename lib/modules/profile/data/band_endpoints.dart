class BandEndpoints {
  static const String userBase = '/api/v1/user/bands';
  static const String publicBase = '/api/v1/public/bands';
  static const String create = '$userBase/create';
  static const String myBands = '$userBase/my';
  static const String receivedInvitations = '$userBase/invitations/received';

  static String byId(String bandId) => '$userBase/$bandId';
  static String publicById(String bandId) => '$publicBase/$bandId';
  static String pendingInvitations(String bandId) =>
      '$userBase/${Uri.encodeComponent(bandId)}/invitations/pending';
  static String currentReceivedInvitation(String bandId) =>
      '$userBase/${Uri.encodeComponent(bandId)}/invitations/received/current';
  static String invite(String bandId, String invitedUserId, {String? message}) {
    final query = <String, String>{'invitedUserId': invitedUserId};
    if (message != null && message.trim().isNotEmpty) {
      query['message'] = message.trim();
    }
    final uri = Uri(path: '$userBase/$bandId/invite', queryParameters: query);
    return uri.toString();
  }

  static String acceptInvite(String bandId) => '$userBase/$bandId/accept';
  static String rejectInvite(String bandId) => '$userBase/$bandId/reject';
  static String removeMember(String bandId, String userId) =>
      '$userBase/$bandId/remove/$userId';
  static String leave(String bandId) => '$userBase/$bandId/leave';
  static String memberTitle(String bandId, String userId) =>
      '$userBase/${Uri.encodeComponent(bandId)}/members/${Uri.encodeComponent(userId)}/title';
  static String delete(String bandId) => '$userBase/$bandId/delete';
}
