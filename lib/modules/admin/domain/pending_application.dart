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

class PendingApplication {
  const PendingApplication({
    required this.id,
    required this.businessName,
    required this.applicantUsername,
    required this.location,
    required this.appliedAt,
    this.address,
  });

  final String id;
  final String businessName;
  final String applicantUsername;
  final String location;
  final DateTime appliedAt;
  final String? address;

  factory PendingApplication.fromJson(Object? data) {
    final json = data as Map;
    if (json['status'] != 'PENDING') {
      throw const FormatException('Expected a pending application');
    }
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
      address: json['address'] as String?,
    );
  }
}
