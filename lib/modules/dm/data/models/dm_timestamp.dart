/// DM LocalDateTime fields are serialized as UTC wall-clock values without a
/// zone. Keep explicit offsets when present, and let the UI convert to local.
DateTime? parseDmTimestamp(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || parsed.isUtc) return parsed;
  return DateTime.tryParse('${raw}Z');
}
