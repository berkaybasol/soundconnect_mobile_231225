import 'collab_actor.dart';

class CollabReview {
  const CollabReview({
    required this.id,
    required this.jobId,
    required this.reviewer,
    required this.target,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String jobId;
  final CollabActor reviewer;
  final CollabActor target;
  final int rating;
  final String? comment;
  final DateTime createdAt;
}
