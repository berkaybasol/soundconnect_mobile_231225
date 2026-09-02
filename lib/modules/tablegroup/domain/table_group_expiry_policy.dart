import 'dart:async';

const Duration tableGroupMaximumMeetingLead = Duration(hours: 24);

typedef TableGroupDayTimerFactory =
    Timer Function(Duration delay, void Function() callback);

/// Schedules a single refresh at the next local calendar-day boundary.
///
/// A one-shot timer is re-armed after each callback so DST-length days are
/// calculated from the current wall clock instead of assuming 24 hours. The
/// disposed guard also protects a callback that was already queued while its
/// owning widget was being removed.
class TableGroupLocalDayRefreshScheduler {
  TableGroupLocalDayRefreshScheduler({
    required DateTime Function() now,
    required void Function() onRefresh,
    TableGroupDayTimerFactory timerFactory = Timer.new,
  }) : _now = now,
       _onRefresh = onRefresh,
       _timerFactory = timerFactory;

  final DateTime Function() _now;
  final void Function() _onRefresh;
  final TableGroupDayTimerFactory _timerFactory;

  Timer? _timer;
  bool _disposed = false;

  void start() {
    if (_disposed || _timer != null) return;
    _schedule();
  }

  void reschedule({bool refresh = false}) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    if (refresh) {
      _onRefresh();
      if (_disposed) return;
    }
    _schedule();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    if (_disposed) return;
    _timer = _timerFactory(
      tableGroupTimeUntilNextLocalDay(_now()),
      _handleDayBoundary,
    );
  }

  void _handleDayBoundary() {
    _timer = null;
    if (_disposed) return;
    _onRefresh();
    if (!_disposed) _schedule();
  }
}

Duration tableGroupTimeUntilNextLocalDay(DateTime now) {
  final localNow = now.toLocal();
  final nextDay = DateTime(localNow.year, localNow.month, localNow.day + 1);
  final delay = nextDay.difference(localNow);
  return delay > Duration.zero ? delay : const Duration(milliseconds: 1);
}

/// Formats the user-selected gathering instant without losing its calendar day.
///
/// Table groups may meet today or tomorrow, so a clock-only label is ambiguous
/// around midnight. Date comparisons use the local calendar components rather
/// than elapsed durations to remain correct across daylight-saving changes.
String formatTableGroupMeetingAt(DateTime? value, {DateTime? now}) {
  if (value == null) return '--:--';
  final localValue = value.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final valueDay = DateTime.utc(
    localValue.year,
    localValue.month,
    localValue.day,
  );
  final nowDay = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final dayDelta = valueDay.difference(nowDay).inDays;
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');
  final clock = '$hour:$minute';
  if (dayDelta == 0) return 'Bugün $clock';
  if (dayDelta == 1) return 'Yarın $clock';
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  return '$day.$month.${localValue.year} $clock';
}

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
