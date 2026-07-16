import '../../domain/entities/admin_venue_application.dart';

class AdminVenueApplicationModel extends AdminVenueApplication {
  const AdminVenueApplicationModel({
    required super.id,
    required super.applicantUsername,
    required super.venueName,
    required super.venueAddress,
    required super.phone,
    required super.status,
    super.applicationDate,
    super.decisionDate,
  });

  factory AdminVenueApplicationModel.fromJson(Map<String, dynamic> json) {
    return AdminVenueApplicationModel(
      id: json['id']?.toString() ?? '',
      applicantUsername: json['applicantUsername']?.toString() ?? '',
      venueName: json['venueName']?.toString() ?? '',
      venueAddress: json['venueAddress']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: parseAdminVenueApplicationStatus(json['status']),
      applicationDate: DateTime.tryParse(
        json['applicationDate']?.toString() ?? '',
      ),
      decisionDate: DateTime.tryParse(json['decisionDate']?.toString() ?? ''),
    );
  }
}
