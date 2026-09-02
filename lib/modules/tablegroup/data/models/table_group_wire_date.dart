final RegExp _rfc3339InstantPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  r'(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$',
);

/// Parses only an RFC3339 timestamp with an explicit UTC/offset suffix.
///
/// A missing zone is a wire-contract violation. It must not be interpreted as
/// either the device timezone or a hard-coded Istanbul wall clock.
DateTime? parseTableGroupWireDate(Object? value) {
  if (value is! String || value.isEmpty || value != value.trim()) return null;
  final match = _rfc3339InstantPattern.firstMatch(value);
  if (match == null) return null;

  int component(int group) => int.parse(match.group(group)!);
  final year = component(1);
  final month = component(2);
  final day = component(3);
  final hour = component(4);
  final minute = component(5);
  final second = component(6);
  final calendar = DateTime.utc(year, month, day, hour, minute, second);
  if (calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      calendar.hour != hour ||
      calendar.minute != minute ||
      calendar.second != second) {
    return null;
  }

  final zone = match.group(8)!;
  if (zone != 'Z') {
    final offsetHour = int.parse(zone.substring(1, 3));
    final offsetMinute = int.parse(zone.substring(4, 6));
    if (offsetHour > 23 || offsetMinute > 59) return null;
  }

  return DateTime.tryParse(value)?.toUtc();
}
