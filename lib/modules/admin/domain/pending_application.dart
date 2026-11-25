import '../../../core/auth/auth_session.dart';

enum ApplicationKind {
  venue('Mekân', 'venue', 'MANAGE_VENUE_APPLICATIONS'),
  studio('Stüdyo', 'studio', 'MANAGE_STUDIO_APPLICATIONS');

  const ApplicationKind(this.label, this.pathName, this.permission);
  final String label;
  final String pathName;
  final String permission;

  bool canRead(AuthSession session) =>
      session.isAuthenticated &&
      session.userId?.isNotEmpty == true &&
      session.isActive &&
      session.isAdmin &&
      !session.isVenueApplicationSession &&
      !session.requiresListenerProfileChoice &&
      !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
      session.permissions.contains('ADMIN_PANEL_ACCESS') &&
      session.permissions.contains(permission);
}

enum ApplicationReviewStatus {
  pending('PENDING', 'İnceleme bekliyor'),
  approved('APPROVED', 'Onaylandı'),
  rejected('REJECTED', 'Reddedildi');

  const ApplicationReviewStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static ApplicationReviewStatus parse(Object? value) => values.firstWhere(
    (status) => value == status.wireValue,
    orElse: () => throw const FormatException('Unknown application status'),
  );
}

const maxApplicationRejectionLength = 500;

String? applicationRejectionError(String value) {
  final reason = value.trim();
  if (reason.isEmpty) return 'Ret gerekçesini yaz.';
  if (reason.length > maxApplicationRejectionLength) {
    return 'En fazla $maxApplicationRejectionLength karakter kullan.';
  }
  return null;
}

class PendingApplication {
  const PendingApplication({
    required this.id,
    required this.businessName,
    required this.applicantUsername,
    required this.location,
    required this.appliedAt,
    this.status = ApplicationReviewStatus.pending,
    this.address,
    this.phone,
    this.reviewedByUsername,
    this.decisionDate,
    this.rejectionReason,
  });

  final String id;
  final String businessName;
  final String applicantUsername;
  final String location;
  final DateTime appliedAt;
  final ApplicationReviewStatus status;
  final String? address;
  final String? phone;
  final String? reviewedByUsername;
  final DateTime? decisionDate;
  final String? rejectionReason;

  factory PendingApplication.fromJson(Object? data) {
    final json = data as Map;
    final decisionDate = json['decisionDate'] as String?;
    return PendingApplication(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      applicantUsername: json['applicantUsername'] as String,
      location:
          [json['cityName'], json['districtName'], json['neighborhoodName']]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(' / '),
      appliedAt: DateTime.parse(json['applicationDate'] as String),
      status: ApplicationReviewStatus.parse(json['status']),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      reviewedByUsername: json['reviewedByUsername'] as String?,
      decisionDate: decisionDate == null ? null : DateTime.parse(decisionDate),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
