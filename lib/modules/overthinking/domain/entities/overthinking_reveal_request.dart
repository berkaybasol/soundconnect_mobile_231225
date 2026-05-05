class OverthinkingRevealRequest {
  final String id;
  final String postId;
  final String postTitle;
  final String requesterId;
  final String requesterUsername;
  final String authorId;
  final String status;
  final DateTime? createdAt;

  const OverthinkingRevealRequest({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.requesterId,
    required this.requesterUsername,
    required this.authorId,
    required this.status,
    required this.createdAt,
  });
}
