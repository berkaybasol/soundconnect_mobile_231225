import '../../domain/entities/studio_page.dart';

Map<String, dynamic> studioJsonObject(Object? value, String context) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
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
  final value = json[key]?.toString().trim() ?? '';
  if (!allowEmpty && value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? studioJsonNullableString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

int studioJsonInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('$key must be an integer');
  return parsed;
}

bool studioJsonBool(Map<String, dynamic> json, String key, {bool? fallback}) {
  final value = json[key];
  if (value is bool) return value;
  if (fallback != null) return fallback;
  throw FormatException('$key must be a boolean');
}

DateTime studioJsonDate(Map<String, dynamic> json, String key) {
  final value = studioJsonString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO date');
  return DateTime(parsed.year, parsed.month, parsed.day);
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

StudioPage<T> studioPageFromJson<T>(
  Object? value,
  T Function(Object? value) itemDecoder,
) {
  final json = studioJsonObject(value, 'page');
  final items = studioJsonList(
    json['content'],
    'page.content',
  ).map(itemDecoder).toList(growable: false);
  final pageIndex = studioJsonInt(json, 'number');
  final pageSize = studioJsonInt(json, 'size');
  final totalItems = studioJsonInt(json, 'totalElements');
  final totalPages = studioJsonInt(json, 'totalPages');
  return StudioPage<T>(
    items: items,
    pageIndex: pageIndex,
    pageSize: pageSize,
    totalItems: totalItems,
    totalPages: totalPages,
    isFirst: studioJsonBool(json, 'first', fallback: pageIndex == 0),
    isLast: studioJsonBool(
      json,
      'last',
      fallback: totalPages == 0 || pageIndex >= totalPages - 1,
    ),
  );
}
