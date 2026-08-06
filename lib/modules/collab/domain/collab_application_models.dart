import 'collab_discovery_models.dart';

class CollabApplicantProfile {
  const CollabApplicantProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.profileKind,
    required this.specialty,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    this.avatarAsset,
  });

  final String id;
  final String name;
  final String initials;
  final CollabProfileKind profileKind;
  final String specialty;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final String? avatarAsset;

  String get subtitle {
    final trimmedSpecialty = specialty.trim();
    if (trimmedSpecialty.isEmpty) return profileKind.label;
    return '${profileKind.label} · $trimmedSpecialty';
  }
}

enum CollabApplicationStatus {
  pending,
  accepted,
  rejected,
  withdrawnByApplicant,
  invalidatedByListingClosure,
}

extension CollabApplicationStatusLabel on CollabApplicationStatus {
  String get label => switch (this) {
    CollabApplicationStatus.pending => 'Bekliyor',
    CollabApplicationStatus.accepted => 'Kabul edildi',
    CollabApplicationStatus.rejected => 'Reddedildi',
    CollabApplicationStatus.withdrawnByApplicant => 'Başvuran geri çekti',
    CollabApplicationStatus.invalidatedByListingClosure =>
      'İlan kapanınca geçersizleşti',
  };
}

class CollabApplicationDraft {
  const CollabApplicationDraft({
    required this.listing,
    required this.profile,
    required this.phoneNumber,
    required this.message,
  });

  final CollabDiscoveryListing listing;
  final CollabApplicantProfile profile;
  final String phoneNumber;
  final String message;

  bool get isOffer => listing.direction == CollabDirection.available;
}
