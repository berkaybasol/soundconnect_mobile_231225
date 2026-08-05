import '../../domain/entities/studio_page.dart';

Map<String, dynamic> studioJsonObject(Object? value, String context) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw FormatException('$context must contain only string keys');
    }
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('$context must be a JSON object');
}

List<Object?> studioJsonList(Object? value, String context) {
  if (value is List) return value.cast<Object?>();
  throw FormatException('$context must be a JSON array');
}

String studioJsonString(
  Map<String, dynamic> json,
  String key, {
  bool allowEmpty = false,
}) {
  final raw = json[key];
  if (raw is! String) throw FormatException('$key must be a string');
  final value = raw.trim();
  if (!allowEmpty && value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? studioJsonNullableString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String) throw FormatException('$key must be a string');
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

int studioJsonInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

bool studioJsonBool(Map<String, dynamic> json, String key, {bool? fallback}) {
  final value = json[key];
  if (value is bool) return value;
  if (value == null && fallback != null) return fallback;
  throw FormatException('$key must be a boolean');
}

DateTime studioJsonDate(Map<String, dynamic> json, String key) {
  final value = studioJsonString(json, key);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('$key must be an ISO local date');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO local date');
  final date = DateTime(parsed.year, parsed.month, parsed.day);
  if (_studioIsoDate(date) != value) {
    throw FormatException('$key must be a valid ISO local date');
  }
  return date;
}

DateTime studioJsonDateTime(Map<String, dynamic> json, String key) {
  final value = studioJsonString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO date-time');
  return parsed;
}

DateTime? studioJsonNullableDateTime(Map<String, dynamic> json, String key) {
  final value = studioJsonNullableString(json, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO date-time');
  return parsed;
}

DateTime studioJsonInstant(Map<String, dynamic> json, String key) {
  final value = studioJsonString(json, key);
  if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw FormatException('$key must include a UTC offset');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO instant');
  return parsed.toUtc();
}

DateTime? studioJsonNullableInstant(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return studioJsonInstant(json, key);
}

String studioJsonHttpUrl(Map<String, dynamic> json, String key) {
  final value = studioJsonString(json, key);
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme.toLowerCase() != 'http' &&
          uri.scheme.toLowerCase() != 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      RegExp(r'\s').hasMatch(value)) {
    throw FormatException('$key must be an absolute HTTP(S) URL');
  }
  return value;
}

StudioPage<T> studioPageFromJson<T>(
  Object? value,
  T Function(Object? value) itemDecoder,
) {
  final json = studioJsonObject(value, 'page');
  final items = studioJsonList(
    json['content'],
    'page.content',
  ).map(itemDecoder).toList(growable: false);
  final pageKey = json.containsKey('page') ? 'page' : 'number';
  final pageIndex = studioJsonInt(json, pageKey);
  final pageSize = studioJsonInt(json, 'size');
  final totalItems = studioJsonInt(json, 'totalElements');
  final totalPages = studioJsonInt(json, 'totalPages');
  final expectedTotalPages = pageSize < 1 || totalItems == 0
      ? 0
      : (totalItems + pageSize - 1) ~/ pageSize;
  if (pageIndex < 0 ||
      pageSize < 1 ||
      totalItems < 0 ||
      totalPages < 0 ||
      (totalPages == 0 && totalItems != 0) ||
      totalPages != expectedTotalPages ||
      (totalPages > 0 && pageIndex >= totalPages && items.isNotEmpty) ||
      items.length > pageSize ||
      items.length > totalItems) {
    throw const FormatException('page metadata is inconsistent');
  }
  final isFirst = studioJsonBool(json, 'first', fallback: pageIndex == 0);
  final isLast = studioJsonBool(
    json,
    'last',
    fallback: totalPages == 0 || pageIndex >= totalPages - 1,
  );
  if (isFirst != (pageIndex == 0) ||
      isLast != (totalPages == 0 || pageIndex >= totalPages - 1)) {
    throw const FormatException('page boundary flags are inconsistent');
  }
  return StudioPage<T>(
    items: items,
    pageIndex: pageIndex,
    pageSize: pageSize,
    totalItems: totalItems,
    totalPages: totalPages,
    isFirst: isFirst,
    isLast: isLast,
  );
}

String _studioIsoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
