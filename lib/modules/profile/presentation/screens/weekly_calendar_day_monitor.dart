import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/weekly_calendar_date_policy.dart';

/// Re-evaluates cached calendar dates even when no network response arrives.
mixin WeeklyCalendarDayMonitor<T extends StatefulWidget> on State<T> {
  Timer? _calendarTimer;
  late final AppLifecycleListener _calendarLifecycle;
  late DateTime calendarDay;

  DateTime calendarNow() => DateTime.now();
  void onCalendarDayChanged() {}
  void onCalendarResumed({required bool dayChanged}) {}

  @override
  void initState() {
    super.initState();
    calendarDay = WeeklyCalendarDatePolicy.today(calendarNow());
    _calendarLifecycle = AppLifecycleListener(
      onResume: () {
        final changed = _checkCalendarDay();
        onCalendarResumed(dayChanged: changed);
      },
    );
    _scheduleCalendarDay();
  }

  bool _checkCalendarDay() {
    if (!mounted) return false;
    final day = WeeklyCalendarDatePolicy.today(calendarNow());
    final changed = day != calendarDay;
    if (changed) {
      setState(() => calendarDay = day);
      onCalendarDayChanged();
    }
    _scheduleCalendarDay();
    return changed;
  }

  void _scheduleCalendarDay() {
    _calendarTimer?.cancel();
    _calendarTimer = Timer(
      WeeklyCalendarDatePolicy.untilNextDay(calendarNow()),
      _checkCalendarDay,
    );
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkCalendarDay();
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
    _calendarLifecycle.dispose();
    super.dispose();
  }
}
