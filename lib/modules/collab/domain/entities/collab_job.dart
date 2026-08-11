import '../collab_types.dart';
import 'collab_actor.dart';
import 'collab_listing.dart';

class CollabJob {
  const CollabJob({
    required this.id,
    required this.version,
    required this.status,
    required this.listing,
    required this.publisher,
    required this.applicant,
    required this.publisherConfirmedCompletion,
    required this.applicantConfirmedCompletion,
    required this.confirmedByMe,
    required this.reviewedByMe,
    this.publisherConfirmedAt,
    this.applicantConfirmedAt,
    this.completedAt,
  });

  final String id;
  final int version;
  final CollabJobStatus status;
  final CollabListing listing;
  final CollabActor publisher;
  final CollabActor applicant;
  final bool publisherConfirmedCompletion;
  final bool applicantConfirmedCompletion;
  final bool confirmedByMe;
  final DateTime? publisherConfirmedAt;
  final DateTime? applicantConfirmedAt;
  final DateTime? completedAt;
  final bool reviewedByMe;

  bool get isCompleted => status == CollabJobStatus.completed;
}
