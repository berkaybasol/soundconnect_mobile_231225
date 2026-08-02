import '../../domain/entities/admin_studio_application.dart';
import '../../domain/entities/admin_venue_application.dart';

class AdminStudioApplicationModel extends AdminStudioApplication {
  const AdminStudioApplicationModel({
    required super.id,
    required super.applicantUsername,
    required super.studioName,
    required super.studioAddress,
    required super.phone,
    required super.cityName,
    required super.districtName,
    required super.neighborhoodName,
    required super.status,
    super.applicationDate,
    super.decisionDate,
    super.rejectionReason,
  });

  factory AdminStudioApplicationModel.fromJson(Map<String, dynamic> json) {
    return AdminStudioApplicationModel(
      id: json['id']?.toString() ?? '',
      applicantUsername: json['applicantUsername']?.toString() ?? '',
      studioName: json['studioName']?.toString() ?? '',
      studioAddress: json['studioAddress']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      cityName: json['cityName']?.toString() ?? '',
      districtName: json['districtName']?.toString() ?? '',
      neighborhoodName: json['neighborhoodName']?.toString() ?? '',
      status: parseAdminVenueApplicationStatus(json['status']),
      applicationDate: DateTime.tryParse(
        json['applicationDate']?.toString() ?? '',
      ),
      decisionDate: DateTime.tryParse(json['decisionDate']?.toString() ?? ''),
      rejectionReason: _stringOrNull(json['rejectionReason']),
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
