class ListenerProfile {
  final String id;
  final String userId;
  final String? username;
  final String? bio;
  final String? profilePictureUrl;
  final int followerCount;
  final int followingCount;

  const ListenerProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.bio,
    required this.profilePictureUrl,
    required this.followerCount,
    required this.followingCount,
  });
}
