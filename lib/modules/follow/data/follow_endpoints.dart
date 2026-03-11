class FollowEndpoints {
  static const String base = '/api/v1/follow';

  static const String follow = '$base/';
  static const String unfollow = '$base/unfollow';
  static String isFollowing(String followerId, String followingId) =>
      '$base/is-following?followerId=$followerId&followingId=$followingId';
  static String countFollowers(String userId) => '$base/count-followers/$userId';
  static String countFollowing(String userId) => '$base/count-following/$userId';
}
