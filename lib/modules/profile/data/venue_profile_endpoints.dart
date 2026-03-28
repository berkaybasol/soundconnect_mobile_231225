class VenueProfileEndpoints {
  static const String userBase = '/api/v1/user/venue-profiles';
  static const String publicBase = '/api/v1/public/venue-profiles';

  static const String myProfiles = '$userBase/me';

  static String myDetail(String venueId) => '$userBase/me/$venueId/detail';

  static String publicDetail(String venueId) => '$publicBase/$venueId';
}
