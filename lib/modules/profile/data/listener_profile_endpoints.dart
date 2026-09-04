class ListenerProfileEndpoints {
  static const String userBase = '/api/v1/user/listener-profiles';
  static const String publicBase = '/api/v1/public/listener-profiles';
  static const String me = '$userBase/me';
  static const String update = '$userBase/update';
  static const String avatar = '$userBase/me/avatar';
  static const String visibility = '$userBase/me/visibility';
  static const String playlists = '$userBase/me/playlists';

  static String publicDetail(String profileId) =>
      '$publicBase/${Uri.encodeComponent(profileId)}';
}
