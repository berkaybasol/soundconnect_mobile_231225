import '../../event/domain/event_discovery_date_policy.dart';

/// Profile calendars use the event's Istanbul business date, not its end time.
abstract final class WeeklyCalendarDatePolicy {
  static DateTime today([DateTime? now]) => EventDiscoveryDatePolicy.today(now);

  static bool contains(DateTime? date, DateTime today) =>
      date != null && EventDiscoveryDatePolicy.contains(date, today);

  static DateTime? parseDisplayDate(String value) {
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static Duration untilNextDay(DateTime now) {
    final day = today(now);
    final midnight = DateTime.utc(
      day.year,
      day.month,
      day.day + 1,
    ).subtract(const Duration(hours: 3));
    return midnight.difference(now.toUtc());
  }
}
