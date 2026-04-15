import '../../domain/entities/listener_profile.dart';

class ListenerProfileModel extends ListenerProfile {
  const ListenerProfileModel({
    required super.id,
    required super.userId,
    required super.username,
    required super.bio,
    required super.profilePictureUrl,
    required super.followerCount,
    required super.followingCount,
  });

  factory ListenerProfileModel.fromJson(Map<String, dynamic> json) {
    return ListenerProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString(),
      bio: json['bio']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
    );
  }
}
