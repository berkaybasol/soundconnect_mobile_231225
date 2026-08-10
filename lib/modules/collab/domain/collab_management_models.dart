import 'collab_application_models.dart';
import 'collab_discovery_models.dart';

enum CollabOwnedListingStatus { open, closed }

extension CollabOwnedListingStatusLabel on CollabOwnedListingStatus {
  String get label => switch (this) {
    CollabOwnedListingStatus.open => 'Açık',
    CollabOwnedListingStatus.closed => 'Kapalı',
  };
}

enum CollabJobStatus { active, completed }

class CollabApplicationRecord {
  const CollabApplicationRecord({
    required this.id,
    required this.listing,
    required this.applicantProfile,
    required this.phoneNumber,
    required this.message,
    required this.status,
    required this.submittedAt,
  });

  final String id;
  final CollabDiscoveryListing listing;
  final CollabApplicantProfile applicantProfile;
  final String phoneNumber;
  final String message;
  final CollabApplicationStatus status;
  final DateTime submittedAt;

  CollabApplicationRecord copyWith({CollabApplicationStatus? status}) {
    return CollabApplicationRecord(
      id: id,
      listing: listing,
      applicantProfile: applicantProfile,
      phoneNumber: phoneNumber,
      message: message,
      status: status ?? this.status,
      submittedAt: submittedAt,
    );
  }
}

class CollabOwnedListingRecord {
  const CollabOwnedListingRecord({
    required this.listing,
    required this.status,
    required this.applicationCount,
    required this.createdAt,
  });

  final CollabDiscoveryListing listing;
  final CollabOwnedListingStatus status;
  final int applicationCount;
  final DateTime createdAt;

  CollabOwnedListingRecord copyWith({
    CollabDiscoveryListing? listing,
    CollabOwnedListingStatus? status,
    int? applicationCount,
  }) {
    return CollabOwnedListingRecord(
      listing: listing ?? this.listing,
      status: status ?? this.status,
      applicationCount: applicationCount ?? this.applicationCount,
      createdAt: createdAt,
    );
  }
}

class CollabJobRecord {
  const CollabJobRecord({
    required this.id,
    required this.application,
    required this.status,
    this.rating,
    this.review,
  });

  final String id;
  final CollabApplicationRecord application;
  final CollabJobStatus status;
  final int? rating;
  final String? review;

  bool get isReviewed => rating != null;

  CollabJobRecord copyWith({
    CollabJobStatus? status,
    int? rating,
    String? review,
  }) {
    return CollabJobRecord(
      id: id,
      application: application,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }
}
