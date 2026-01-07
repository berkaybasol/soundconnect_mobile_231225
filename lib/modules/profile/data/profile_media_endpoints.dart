class ProfileMediaEndpoints {
  static const String base = '/api/v1/profiles';

  static String media({
    required String profileType,
    required String profileId,
  }) {
    return '$base/$profileType/$profileId/media';
  }
}
