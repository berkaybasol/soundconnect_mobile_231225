/// Calendar-date arithmetic for Studio-local values.
///
/// API dates are civil dates, not instants. Performing arithmetic on local
/// midnight values with [DateTime.difference] or `Duration(days: ...)` is
/// incorrect across daylight-saving transitions. These helpers use UTC only
/// as a timezone-neutral ordinal and preserve the input's UTC/local shape.
DateTime studioCivilDate(DateTime value) => value.isUtc
    ? DateTime.utc(value.year, value.month, value.day)
    : DateTime(value.year, value.month, value.day);

DateTime studioAddCivilDays(DateTime value, int days) => value.isUtc
    ? DateTime.utc(value.year, value.month, value.day + days)
    : DateTime(value.year, value.month, value.day + days);

int studioCivilDaysBetween(DateTime start, DateTime end) {
  final startOrdinal = DateTime.utc(start.year, start.month, start.day);
  final endOrdinal = DateTime.utc(end.year, end.month, end.day);
  return endOrdinal.difference(startOrdinal).inDays;
}

int studioCivilRangeLength(DateTime start, DateTime end) =>
    studioCivilDaysBetween(start, end) + 1;

/// Resolves the date anchor used by Studio calendars.
///
/// Remote and editable calendars must be anchored to the server-authored
/// Studio date. A device-date fallback is allowed only for read-only,
/// presentation-only fixtures that have no remote repository.
DateTime? studioCalendarReferenceDate({
  required DateTime? serverDate,
  required bool editable,
  required bool hasRemoteRepository,
  DateTime? presentationFallback,
}) {
  if (serverDate != null) return studioCivilDate(serverDate);
  if (editable || hasRemoteRepository) return null;
  final fallback = presentationFallback;
  return fallback == null ? null : studioCivilDate(fallback);
}
