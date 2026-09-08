final _commentDateTimePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}'
  r'(?::\d{2}(?:[.,]\d{1,9})?)?'
  r'([zZ]|[+-]\d{2}(?::?\d{2})?)?$',
);

/// Comment timestamps are UTC instants. Legacy responses serialized the UTC
/// auditing LocalDateTime without a zone. Apply UTC before parsing those values
/// so the device timezone (including DST transitions) cannot change the instant.
/// Explicit offsets from newer responses always retain their original meaning.
DateTime? parseCommentWireDate(Object? value) {
  if (value is! String) return null;
  final match = _commentDateTimePattern.firstMatch(value);
  if (match == null) return null;
  final zoned = match[1] == null ? '${value}Z' : value;
  return DateTime.tryParse(zoned)?.toUtc();
}
