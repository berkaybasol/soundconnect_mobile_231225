class FollowRequest {
  final String followerId;
  final String followingId;

  const FollowRequest({
    required this.followerId,
    required this.followingId,
  });

  Map<String, dynamic> toJson() {
    return {
      'followerId': followerId,
      'followingId': followingId,
    };
  }
}
