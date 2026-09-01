const Duration tableGroupMaximumMeetingLead = Duration(hours: 24);

/// Resolves a time-only selection to the next occurrence of that wall time.
///
/// A time that already passed today means tomorrow. The result is clamped to
/// the backend's maximum 24-hour lifetime, including across offset changes.
DateTime resolveTableGroupMeetingAt({
  required DateTime now,
  required int hour,
  required int minute,
}) {
  if (hour < 0 || hour > 23) {
    throw RangeError.range(hour, 0, 23, 'hour');
  }
  if (minute < 0 || minute > 59) {
    throw RangeError.range(minute, 0, 59, 'minute');
  }

  DateTime candidateForDay(int day) => now.isUtc
      ? DateTime.utc(now.year, now.month, day, hour, minute)
      : DateTime(now.year, now.month, day, hour, minute);

  var candidate = candidateForDay(now.day);
  if (!candidate.isAfter(now)) {
    candidate = candidateForDay(now.day + 1);
  }

  final latestAllowed = now.add(tableGroupMaximumMeetingLead);
  return candidate.isAfter(latestAllowed) ? latestAllowed : candidate;
}
