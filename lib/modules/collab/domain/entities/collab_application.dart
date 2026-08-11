import '../collab_types.dart';
import 'collab_actor.dart';
import 'collab_listing.dart';

class CollabApplication {
  const CollabApplication({
    required this.id,
    required this.version,
    required this.listing,
    required this.applicant,
    required this.message,
    required this.status,
    required this.submittedAt,
    required this.statusChangedAt,
    this.phone,
    this.decidedAt,
  });

  final String id;
  final int version;
  final CollabListing listing;
  final CollabActor applicant;

  /// Only populated for the applicant and listing publisher. It must never be
  /// copied into discovery or notification payloads.
  final String? phone;
  final String message;
  final CollabApplicationStatus status;
  final DateTime submittedAt;
  final DateTime statusChangedAt;
  final DateTime? decidedAt;

  bool get isPending => status == CollabApplicationStatus.pending;

  CollabApplication copyWith({
    int? version,
    CollabListing? listing,
    CollabApplicationStatus? status,
    DateTime? statusChangedAt,
    DateTime? decidedAt,
  }) => CollabApplication(
    id: id,
    version: version ?? this.version,
    listing: listing ?? this.listing,
    applicant: applicant,
    phone: phone,
    message: message,
    status: status ?? this.status,
    submittedAt: submittedAt,
    statusChangedAt: statusChangedAt ?? this.statusChangedAt,
    decidedAt: decidedAt ?? this.decidedAt,
  );
}
