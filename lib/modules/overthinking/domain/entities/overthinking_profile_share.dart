import 'overthinking_post.dart';

class OverthinkingProfileShareState {
  const OverthinkingProfileShareState({
    required this.postId,
    required this.shareId,
    required this.publishedOnProfile,
    required this.note,
    required this.publishedAt,
    required this.canPublish,
  });

  final String postId;
  final String? shareId;
  final bool publishedOnProfile;
  final String? note;
  final DateTime? publishedAt;
  final bool canPublish;
}

class OverthinkingProfileShare {
  const OverthinkingProfileShare({
    required this.shareId,
    required this.note,
    required this.publishedAt,
    required this.post,
  });

  final String shareId;
  final String? note;
  final DateTime publishedAt;
  final OverthinkingPost post;
}
