enum AdminVenueApplicationStatus { pending, approved, rejected, unknown }

class AdminVenueApplication {
  final String id;
  final String applicantUsername;
  final String venueName;
  final String venueAddress;
  final String phone;
  final AdminVenueApplicationStatus status;
  final DateTime? applicationDate;
  final DateTime? decisionDate;

  const AdminVenueApplication({
    required this.id,
    required this.applicantUsername,
    required this.venueName,
    required this.venueAddress,
    required this.phone,
    required this.status,
    this.applicationDate,
    this.decisionDate,
  });
}

extension AdminVenueApplicationStatusApi on AdminVenueApplicationStatus {
  String get apiValue => switch (this) {
    AdminVenueApplicationStatus.pending => 'PENDING',
    AdminVenueApplicationStatus.approved => 'APPROVED',
    AdminVenueApplicationStatus.rejected => 'REJECTED',
    AdminVenueApplicationStatus.unknown => 'PENDING',
  };

  String get label => switch (this) {
    AdminVenueApplicationStatus.pending => 'Beklemede',
    AdminVenueApplicationStatus.approved => 'Onaylandı',
    AdminVenueApplicationStatus.rejected => 'Reddedildi',
    AdminVenueApplicationStatus.unknown => 'Bilinmiyor',
  };
}

AdminVenueApplicationStatus parseAdminVenueApplicationStatus(Object? value) {
  final raw = value?.toString().trim().toUpperCase();
  return switch (raw) {
    'PENDING' => AdminVenueApplicationStatus.pending,
    'APPROVED' => AdminVenueApplicationStatus.approved,
    'REJECTED' => AdminVenueApplicationStatus.rejected,
    _ => AdminVenueApplicationStatus.unknown,
  };
}
