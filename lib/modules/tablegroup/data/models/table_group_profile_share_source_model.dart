import '../../domain/entities/table_group_profile_share.dart';
import 'table_group_wire_date.dart';

/// Decodes the same public table snapshot used by profile posts and feed posts.
///
/// Incomplete or inconsistent snapshots must not invent a location, capacity,
/// or active lifetime. Callers can present an unavailable source on failure.
TableGroupProfileShareSource parseTableGroupProfileShareSource(Object? raw) {
  final json = _map(raw);
  final status = _text(json['status']);
  if (!const {'ACTIVE', 'INACTIVE', 'CANCELLED'}.contains(status)) {
    throw const FormatException('Invalid table status');
  }
  final capacity = _count(json['maxPersonCount']);
  final accepted = _count(json['acceptedCount']);
  if (capacity == 0 || accepted > capacity) {
    throw const FormatException('Invalid table capacity');
  }
  final description = _optionalText(json['description']);
  final meetingAt = json['meetingAt'] == null
      ? null
      : _instant(json['meetingAt']);
  final expiresAt = json['expiresAt'] == null
      ? null
      : _instant(json['expiresAt']);
  if (description == null || meetingAt == null || expiresAt == null) {
    throw const FormatException('Table preview is incomplete');
  }
  return TableGroupProfileShareSource(
    id: _id(json['id']),
    description: description,
    venueName: _optionalText(json['venueName']),
    cityName: _text(json['cityName']),
    districtName: _optionalText(json['districtName']),
    meetingAt: meetingAt,
    expiresAt: expiresAt,
    status: status,
    maxPersonCount: capacity,
    acceptedCount: accepted,
  );
}

int _count(Object? raw) {
  if (raw is! int || raw < 0 || raw > 9007199254740991) {
    throw const FormatException('Invalid count');
  }
  return raw;
}

String _text(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('Invalid text');
  }
  return raw.trim();
}

String? _optionalText(Object? raw) {
  if (raw == null) return null;
  if (raw is! String) throw const FormatException('Invalid optional text');
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Invalid object');
  }
  return raw;
}

String _id(Object? raw) {
  if (raw is! String ||
      raw.trim().isEmpty ||
      raw != raw.trim() ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(raw)) {
    throw const FormatException('Invalid identity');
  }
  return raw;
}

DateTime _instant(Object? raw) {
  final instant = parseTableGroupWireDate(raw);
  if (instant == null) {
    throw const FormatException('Invalid publication time');
  }
  return instant;
}
