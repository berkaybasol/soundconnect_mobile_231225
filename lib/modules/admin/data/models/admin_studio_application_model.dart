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
    final statusValue = _requiredString(json, 'status');
    if (!const <String>{
      'PENDING',
      'APPROVED',
      'REJECTED',
    }.contains(statusValue)) {
      throw const FormatException('Invalid Studio application status');
    }
    return AdminStudioApplicationModel(
      id: _requiredString(json, 'id'),
      applicantUsername: _requiredString(json, 'applicantUsername'),
      studioName: _requiredString(json, 'studioName'),
      studioAddress: _requiredString(json, 'studioAddress'),
      phone: _requiredString(json, 'phone'),
      cityName: _requiredString(json, 'cityName'),
      districtName: _requiredString(json, 'districtName'),
      neighborhoodName: _requiredString(json, 'neighborhoodName'),
      status: parseAdminVenueApplicationStatus(statusValue),
      applicationDate: _parseRequiredUtcInstant(
        json['applicationDate'],
        'applicationDate',
      ),
      decisionDate: _parseOptionalUtcInstant(
        json['decisionDate'],
        'decisionDate',
      ),
      rejectionReason: _stringOrNull(json['rejectionReason']),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid $key');
    }
    return value.trim();
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Expected an optional string');
    }
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime _parseRequiredUtcInstant(Object? value, String fieldName) {
    final parsed = _parseOptionalUtcInstant(value, fieldName);
    if (parsed == null) throw FormatException('Missing $fieldName');
    return parsed;
  }

  static DateTime? _parseOptionalUtcInstant(Object? value, String fieldName) {
    if (value == null) return null;
    if (value is! String) throw FormatException('Invalid $fieldName');
    final raw = value.trim();
    final hasOffset =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    final parsed = hasOffset ? DateTime.tryParse(raw)?.toUtc() : null;
    if (parsed == null) throw FormatException('Invalid $fieldName');
    return parsed;
  }
}
