class StudioProfileEndpoints {
  static const String userBase = '/api/v1/user/studio-profiles';
  static const String publicBase = '/api/v1/public/studio-profiles';

  static const String me = '$userBase/me';
  static const String update = '$userBase/update';

  static String publicDetail(String profileId) =>
      '$publicBase/${Uri.encodeComponent(profileId)}';
}
