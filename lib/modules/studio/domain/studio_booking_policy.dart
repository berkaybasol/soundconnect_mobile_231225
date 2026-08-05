import 'entities/studio_reservation.dart';
import 'studio_civil_date.dart';

/// Server-authored booking window expressed in the studio's local wall clock.
///
/// The API deliberately sends local date/time components alongside its IANA
/// zone id. Keeping the comparison in those components avoids accidentally
/// applying the mobile device's timezone to studio business rules.
class StudioBookingCalendarPolicy {
  StudioBookingCalendarPolicy({
    required DateTime todayLocalDate,
    required String currentLocalTime,
    required DateTime latestBookableLocalDateTime,
  }) : todayLocalDate = _dateOnly(todayLocalDate),
       currentLocalDateTime = _combine(todayLocalDate, currentLocalTime),
       latestBookableLocalDateTime = _localDateTime(
         latestBookableLocalDateTime,
       ) {
    if (this.latestBookableLocalDateTime.isBefore(currentLocalDateTime)) {
      throw ArgumentError.value(
        latestBookableLocalDateTime,
        'latestBookableLocalDateTime',
        'The latest booking boundary cannot precede the studio clock.',
      );
    }
  }

  final DateTime todayLocalDate;
  final DateTime currentLocalDateTime;
  final DateTime latestBookableLocalDateTime;

  DateTime get latestBookableLocalDate =>
      _dateOnly(latestBookableLocalDateTime);

  bool containsDate(DateTime date) {
    final normalized = _dateOnly(date);
    return !normalized.isBefore(todayLocalDate) &&
        !normalized.isAfter(latestBookableLocalDate);
  }

  DateTime? shiftDate(DateTime date, int days) {
    final shifted = studioAddCivilDays(_dateOnly(date), days);
    return containsDate(shifted) ? shifted : null;
  }

  bool canStartAt(DateTime date, int hour) {
    final normalized = _dateOnly(date);
    if (!containsDate(normalized) || hour < 0 || hour > 23) return false;
    final candidate = DateTime(
      normalized.year,
      normalized.month,
      normalized.day,
      hour,
    );
    return candidate.isAfter(currentLocalDateTime) &&
        !candidate.isAfter(latestBookableLocalDateTime);
  }

  static DateTime _combine(DateTime date, String localTime) {
    final normalized = localTime.trim();
    if (!RegExp(
      r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
    ).hasMatch(normalized)) {
      throw FormatException('Invalid studio local time: $localTime');
    }
    final parsed = DateTime.tryParse('1970-01-01T$normalized');
    if (parsed == null) {
      throw FormatException('Invalid studio local time: $localTime');
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static DateTime _dateOnly(DateTime value) => studioCivilDate(value);

  static DateTime _localDateTime(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

class StudioReservationOwnerCapabilities {
  const StudioReservationOwnerCapabilities({
    required this.canApprove,
    required this.canReject,
    required this.canCancel,
  });

  factory StudioReservationOwnerCapabilities.evaluate({
    required StudioReservationStatus status,
    required DateTime startsAt,
    required bool completed,
    required DateTime? now,
  }) {
    if (now == null) return none;
    final hasNotStarted = startsAt.toUtc().isAfter(now.toUtc());
    if (completed || !hasNotStarted) {
      return none;
    }
    return StudioReservationOwnerCapabilities(
      canApprove: status.isPending,
      canReject: status.isPending,
      canCancel: status.isPending || status.isConfirmed,
    );
  }

  final bool canApprove;
  final bool canReject;
  final bool canCancel;

  static const none = StudioReservationOwnerCapabilities(
    canApprove: false,
    canReject: false,
    canCancel: false,
  );

  bool get hasMutation => canApprove || canReject || canCancel;
}
