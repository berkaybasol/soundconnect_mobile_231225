class BandFollowEndpoints {
  static const String base = '/api/v1/band-follows';

  static String countFollowers(String bandId) =>
      '$base/bands/$bandId/followers/count';
}
