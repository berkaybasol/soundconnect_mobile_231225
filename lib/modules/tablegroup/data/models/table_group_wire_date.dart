const Duration _legacyIstanbulUtcOffset = Duration(hours: 3);

DateTime? parseTableGroupWireDate(Object? value) {
  return _parseTableGroupWireDate(value, legacyUtcOffset: Duration.zero);
}

/// Parses `expiresAt`, whose legacy zone-less form represented an
/// Europe/Istanbul wall-clock value. Table-group expiries are contemporary;
/// Türkiye has used UTC+03:00 continuously since 2016.
DateTime? parseTableGroupExpiryWireDate(Object? value) {
  return _parseTableGroupWireDate(
    value,
    legacyUtcOffset: _legacyIstanbulUtcOffset,
  );
}

DateTime? _parseTableGroupWireDate(
  Object? value, {
  required Duration legacyUtcOffset,
}) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;

  // New Instant/offset DTOs already include their zone. Legacy values are
  // interpreted by their field-specific contract and normalized at the edge.
  final hasExplicitZone = RegExp(
    r'(?:z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);
  final parsed = DateTime.tryParse(hasExplicitZone ? raw : '${raw}Z');
  if (parsed == null) return null;
  final utc = parsed.toUtc();
  return hasExplicitZone ? utc : utc.subtract(legacyUtcOffset);
}
