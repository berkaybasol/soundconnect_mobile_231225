import 'admin_venue_application.dart';

class AdminStudioApplication {
  final String id;
  final String applicantUsername;
  final String studioName;
  final String studioAddress;
  final String phone;
  final String cityName;
  final String districtName;
  final String neighborhoodName;
  final AdminVenueApplicationStatus status;
  final DateTime? applicationDate;
  final DateTime? decisionDate;
  final String? rejectionReason;

  const AdminStudioApplication({
    required this.id,
    required this.applicantUsername,
    required this.studioName,
    required this.studioAddress,
    required this.phone,
    required this.cityName,
    required this.districtName,
    required this.neighborhoodName,
    required this.status,
    this.applicationDate,
    this.decisionDate,
    this.rejectionReason,
  });
}
