import '../../domain/profile_contact_uri.dart';

Map<String, dynamic> listenerProfileJsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException(
        'Listener profile JSON object keys must be strings',
      );
    }
    return Map<String, dynamic>.from(value);
  }
  throw const FormatException('Listener profile must be a JSON object');
}

String listenerRequiredString(Map<String, dynamic> json, String field) {
  final value = listenerOptionalString(json[field], field);
  if (value == null) {
    throw FormatException('$field must be a non-blank string');
  }
  return value;
}

String? listenerOptionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$field must be a string');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? listenerOptionalHttpUrl(Object? value, String field) {
  final raw = listenerOptionalString(value, field);
  if (raw == null) return null;
  final uri = profileHttpUri(raw);
  if (uri == null) {
    throw FormatException('$field must be an absolute HTTP(S) URL');
  }
  return uri.toString();
}

int listenerRequiredNonNegativeInt(Map<String, dynamic> json, String field) {
  final value = listenerOptionalNonNegativeInt(json, field);
  if (value == null) {
    throw FormatException('$field must be a non-negative integer');
  }
  return value;
}

int? listenerOptionalNonNegativeInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  final int? parsed = switch (value) {
    int number => number,
    num number when number.isFinite && number == number.toInt() =>
      number.toInt(),
    _ => null,
  };
  if (parsed == null || parsed < 0) {
    throw FormatException('$field must be a non-negative integer');
  }
  return parsed;
}

bool listenerRequiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

DateTime? listenerOptionalDateTime(Object? value, String field) {
  final raw = listenerOptionalString(value, field);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 date-time');
  }
  return parsed;
}
