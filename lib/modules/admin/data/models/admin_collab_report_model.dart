import '../../domain/entities/admin_collab_report.dart';

class AdminCollabReportModel extends AdminCollabReport {
  const AdminCollabReportModel({
    required super.id,
    required super.version,
    required super.status,
    required super.reason,
    required super.details,
    required super.reportedAt,
    required super.listingId,
    required super.listingTitle,
    required super.listingDescription,
    required super.listingStatusAtReport,
    required super.listingStatus,
    required super.publisherActorId,
    required super.publisherDisplayName,
    required super.cadence,
    required super.wantedType,
    required super.instrumentName,
    required super.branch,
    required super.customSpecialty,
    required super.cityName,
    required super.listingGenres,
    required super.scheduledAt,
    required super.feeAmountMinor,
    required super.currency,
    required super.reporterUserId,
    required super.reviewDecision,
    required super.reviewedByUserId,
    required super.reviewedAt,
    required super.resolutionNote,
  });

  factory AdminCollabReportModel.fromJson(Object? value) {
    final json = _object(value);
    final version = json['version'];
    if (version is! int || version < 0) {
      throw const FormatException('Collab rapor sürümü geçersiz');
    }
    return AdminCollabReportModel(
      id: _requiredString(json, 'id'),
      version: version,
      status: _status(_requiredString(json, 'status')),
      reason: _reason(_requiredString(json, 'reason')),
      details: _optionalString(json, 'details'),
      reportedAt: _instant(json, 'reportedAt'),
      listingId: _requiredString(json, 'listingId'),
      listingTitle: _requiredString(json, 'listingTitle'),
      listingDescription: _requiredString(json, 'listingDescription'),
      listingStatusAtReport: _requiredString(json, 'listingStatusAtReport'),
      listingStatus: _requiredString(json, 'listingStatus'),
      publisherActorId: _requiredString(json, 'publisherActorId'),
      publisherDisplayName: _requiredString(json, 'publisherDisplayName'),
      cadence: _requiredString(json, 'cadence'),
      wantedType: _requiredString(json, 'wantedType'),
      instrumentName: _optionalSummaryName(json, 'instrument'),
      branch: _optionalString(json, 'branch'),
      customSpecialty: _optionalString(json, 'customSpecialty'),
      cityName: _requiredSummaryName(json, 'city'),
      listingGenres: _stringList(json, 'listingGenres'),
      scheduledAt: _optionalInstant(json, 'scheduledAt'),
      feeAmountMinor: _optionalInt(json, 'feeAmountMinor'),
      currency: _optionalString(json, 'currency'),
      reporterUserId: _requiredString(json, 'reporterUserId'),
      reviewDecision: _optionalDecision(json['reviewDecision']),
      reviewedByUserId: _optionalString(json, 'reviewedByUserId'),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : _instant(json, 'reviewedAt'),
      resolutionNote: _optionalString(json, 'resolutionNote'),
    );
  }
}

AdminCollabReportStatus _status(String value) => switch (value) {
  'OPEN' => AdminCollabReportStatus.open,
  'DISMISSED' => AdminCollabReportStatus.dismissed,
  'ACTIONED' => AdminCollabReportStatus.actioned,
  _ => throw FormatException('Bilinmeyen Collab rapor durumu: $value'),
};

AdminCollabReportReason _reason(String value) => switch (value) {
  'SPAM' => AdminCollabReportReason.spam,
  'INAPPROPRIATE' => AdminCollabReportReason.inappropriate,
  'MISLEADING' => AdminCollabReportReason.misleading,
  'OTHER' => AdminCollabReportReason.other,
  _ => throw FormatException('Bilinmeyen Collab rapor nedeni: $value'),
};

AdminCollabReportDecision? _optionalDecision(Object? value) => switch (value) {
  null => null,
  'DISMISS' => AdminCollabReportDecision.dismiss,
  'REMOVE_LISTING' => AdminCollabReportDecision.removeListing,
  _ => throw FormatException('Bilinmeyen Collab moderasyon kararı: $value'),
};

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, dynamic>.from(value);
  }
  throw const FormatException('Collab raporu bir JSON nesnesi olmalıdır');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field eksik veya geçersiz');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String) throw FormatException('$field geçersiz');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _instant(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw FormatException('$field saat dilimi içermelidir');
  }
  final parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) throw FormatException('$field geçersiz');
  return parsed;
}

DateTime? _optionalInstant(Map<String, dynamic> json, String field) =>
    json[field] == null ? null : _instant(json, field);

int? _optionalInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('$field geçersiz');
}

String? _optionalSummaryName(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return _requiredString(_object(value), 'name');
}

String _requiredSummaryName(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) throw FormatException('$field eksik veya geçersiz');
  return _requiredString(_object(value), 'name');
}

List<String> _stringList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! List) throw FormatException('$field geçersiz');
  final result = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$field geçersiz');
    }
    result.add(item.trim());
  }
  return List<String>.unmodifiable(result);
}
