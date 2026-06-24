class BandFollowEndpoints {
  static const String base = '/api/v1/band-follows';

  static String band(String bandId) => '$base/bands/$bandId';

  static String isFollowing(String bandId) =>
      '$base/bands/$bandId/is-following';

  static String countFollowers(String bandId) =>
      '$base/bands/$bandId/followers/count';
}
