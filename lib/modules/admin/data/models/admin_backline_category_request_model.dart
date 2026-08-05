import '../../domain/entities/admin_backline_category_request.dart';

class AdminBacklineCategoryRequestModel extends AdminBacklineCategoryRequest {
  const AdminBacklineCategoryRequestModel({
    required super.id,
    required super.clientRequestId,
    required super.studioProfileId,
    required super.studioName,
    required super.type,
    required super.requestedName,
    required super.parentCategoryId,
    required super.parentCategoryName,
    required super.proposedChildren,
    required super.requesterNote,
    required super.status,
    required super.resolvedRootCategoryId,
    required super.resolvedCategoryId,
    required super.reviewedByUserId,
    required super.reviewedAt,
    required super.decisionNote,
    required super.createdAt,
  });

  factory AdminBacklineCategoryRequestModel.fromJson(Object? value) {
    final json = _object(value, 'kategori talebi');
    final children =
        _list(json['proposedChildren'], 'proposedChildren')
            .map((value) {
              final child = _object(value, 'kategori talebi alt kategorisi');
              final position = _integer(child, 'position');
              if (position < 0) {
                throw const FormatException('position negatif olamaz');
              }
              return AdminBacklineCategoryRequestChild(
                name: _requiredString(child, 'name'),
                position: position,
                resolvedCategoryId: _optionalString(
                  child,
                  'resolvedCategoryId',
                ),
              );
            })
            .toList(growable: false)
          ..sort((left, right) => left.position.compareTo(right.position));

    return AdminBacklineCategoryRequestModel(
      id: _requiredString(json, 'id'),
      clientRequestId: _requiredString(json, 'clientRequestId'),
      studioProfileId: _requiredString(json, 'studioProfileId'),
      studioName: _requiredString(json, 'studioName'),
      type: _type(_requiredString(json, 'type')),
      requestedName: _requiredString(json, 'requestedName'),
      parentCategoryId: _optionalString(json, 'parentCategoryId'),
      parentCategoryName: _optionalString(json, 'parentCategoryName'),
      proposedChildren: List.unmodifiable(children),
      requesterNote: _optionalString(json, 'requesterNote'),
      status: _status(_requiredString(json, 'status')),
      resolvedRootCategoryId: _optionalString(json, 'resolvedRootCategoryId'),
      resolvedCategoryId: _optionalString(json, 'resolvedCategoryId'),
      reviewedByUserId: _optionalString(json, 'reviewedByUserId'),
      reviewedAt: _optionalInstant(json, 'reviewedAt'),
      decisionNote: _optionalString(json, 'decisionNote'),
      createdAt: json['createdAtUtc'] == null
          ? _requiredDateTime(json, 'createdAt')
          : _requiredInstant(json, 'createdAtUtc'),
    );
  }
}

AdminBacklineCategoryRequestType _type(String value) => switch (value) {
  'ROOT_CATEGORY' => AdminBacklineCategoryRequestType.rootCategory,
  'SUBCATEGORY' => AdminBacklineCategoryRequestType.subcategory,
  _ => throw FormatException('Bilinmeyen kategori talebi türü: $value'),
};

AdminBacklineCategoryRequestStatus _status(String value) => switch (value) {
  'PENDING' => AdminBacklineCategoryRequestStatus.pending,
  'APPROVED' => AdminBacklineCategoryRequestStatus.approved,
  'REJECTED' => AdminBacklineCategoryRequestStatus.rejected,
  'WITHDRAWN' => AdminBacklineCategoryRequestStatus.withdrawn,
  _ => throw FormatException('Bilinmeyen kategori talebi durumu: $value'),
};

Map<String, dynamic> _object(Object? value, String context) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('$context bir JSON nesnesi olmalıdır');
}

List<Object?> _list(Object? value, String field) {
  if (value is List) return value.cast<Object?>();
  throw FormatException('$field bir liste olmalıdır');
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

int _integer(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('$field bir tam sayı olmalıdır');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$field geçersiz');
  return parsed;
}

DateTime _requiredInstant(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw FormatException('$field saat dilimi içermelidir');
  }
  final parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) throw FormatException('$field geçersiz');
  return parsed;
}

DateTime? _optionalInstant(Map<String, dynamic> json, String field) {
  if (json[field] == null) return null;
  return _requiredInstant(json, field);
}
