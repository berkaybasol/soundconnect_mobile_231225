import 'admin_user_directory.dart';

typedef _Json = Map<String, dynamic>;

enum AnalyticsReportSource {
  ga4('GA4'),
  soundConnect('SoundConnect');

  const AnalyticsReportSource(this.label);
  final String label;

  static AnalyticsReportSource fromWire(Object? value) => switch (value) {
    null || 'GA4' => ga4, // Reports from API v33 and earlier used GA4.
    'SOUNDCONNECT' => soundConnect,
    _ => throw const FormatException('Unknown analytics report source'),
  };
}

_Json _object(Object? value) => Map<String, dynamic>.from(value as Map);

int _count(dynamic value) {
  if (value is int && value >= 0) return value;
  throw const FormatException('Invalid analytics count');
}

double _number(dynamic value) {
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  throw const FormatException('Invalid analytics value');
}

DateTime _instant(dynamic value) {
  final time = DateTime.parse(value as String);
  if (!time.isUtc) throw const FormatException('Missing time zone');
  return time;
}

DateTime _day(dynamic value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid report date');
  }
  final parsed = DateTime.parse('${value}T00:00:00Z');
  if (!parsed.toIso8601String().startsWith(value)) {
    throw const FormatException('Invalid report date');
  }
  return parsed;
}

Map<String, int> _counts(dynamic data) =>
    _object(data).map((key, value) => MapEntry(key, _count(value)));

String reportMonth(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

class AdminAnalyticsReport {
  AdminAnalyticsReport._(_Json json)
    : month = json['month'] as String,
      asOf = _instant(json['asOf']),
      coverageStart = json['coverageStart'] == null
          ? null
          : _day(json['coverageStart']),
      liveSource = AnalyticsReportSource.fromWire(json['liveSource']),
      peakSource = AnalyticsReportSource.fromWire(json['peakSource']),
      peakCoverageStart = json['peakCoverageStart'] == null
          ? null
          : _instant(json['peakCoverageStart']),
      live = json['live'] == null ? null : ReportLive(_object(json['live'])),
      membership = json['membership'] == null
          ? null
          : ReportMembership(_object(json['membership'])),
      usage = json['usage'] == null
          ? null
          : ReportUsage(_object(json['usage'])),
      firstWeek = json['firstWeek'] == null
          ? null
          : ReportFirstWeek(_object(json['firstWeek'])),
      peaks = ReportPeaks(_object(json['peaks'])),
      hasIssues = (json['issues'] as List).isNotEmpty;

  final String month;
  final DateTime asOf;
  final DateTime? coverageStart;
  final AnalyticsReportSource liveSource, peakSource;
  final DateTime? peakCoverageStart;
  final ReportLive? live;
  final ReportMembership? membership;
  final ReportUsage? usage;
  final ReportFirstWeek? firstWeek;
  final ReportPeaks peaks;
  final bool hasIssues;

  factory AdminAnalyticsReport.read(
    Object? value,
    String month,
    AdminUserProfileType? profile,
  ) {
    final json = _object(value);
    if (json['month'] != month ||
        json['profileType'] != (profile?.wire ?? 'ALL')) {
      throw const FormatException('Unexpected analytics scope');
    }
    final report = AdminAnalyticsReport._(json);
    final usage = report.usage;
    if (usage != null &&
        [
          ...usage.daily.keys,
          ...usage.dailySections.keys,
        ].any((date) => reportMonth(date) != month)) {
      throw const FormatException('Unexpected analytics day');
    }
    return report;
  }
}

class ReportLive {
  ReportLive(Map<String, dynamic> json)
    : asOf = _instant(json['asOf']),
      members = _count(json['members']),
      guests = _count(json['guests']);
  final DateTime asOf;
  final int members, guests;
}

class ReportMembership {
  ReportMembership(Map<String, dynamic> json)
    : newAccounts = _count(json['newAccounts']),
      deleted = _count(json['deletedAccounts']),
      total = _count(json['totalAccounts']),
      change = json['change'] as int?,
      pending = _count(json['pending']),
      byRole = _counts(json['byRole']),
      pendingByRole = json['pendingByRole'] == null
          ? {}
          : _counts(json['pendingByRole']);
  final int newAccounts, deleted, total, pending;
  final int? change;
  final Map<String, int> byRole, pendingByRole;
}

class ReportUsage {
  ReportUsage(Map<String, dynamic> json)
    : mau = _count(json['mau']),
      avgDau = _number(json['avgDau']),
      activeMinutes = json['minutesPerActiveDay'] == null
          ? null
          : _number(json['minutesPerActiveDay']),
      previousActive = json['previousActive'] == null
          ? null
          : _count(json['previousActive']),
      returned = json['returned'] == null ? null : _count(json['returned']),
      returnRate = json['returnRate'] == null
          ? null
          : _number(json['returnRate']),
      guestMau = json['guestMau'] == null ? null : _count(json['guestMau']),
      totalMilliseconds = _count(json['totalMilliseconds']),
      daily = {
        for (final row in json['daily'] as List)
          _day(row['day']): _count(row['users']),
      },
      hours = {
        for (final row in json['hours'] as List)
          _count(row['hour']): _number(row['users']),
      },
      weekdays = {
        for (final row in json['weekdays'] as List)
          _count(row['weekday']): _number(row['users']),
      },
      sections = {
        for (final row in json['sections'] as List)
          row['section'] as String: ReportSection(_object(row)),
      },
      dailySections = {} {
    for (final row in json['dailySections'] as List) {
      final day = _day(row['day']);
      (dailySections[day] ??= {})[row['section'] as String] = ReportSection(
        _object(row),
      );
    }
    if (hours.keys.any((h) => h > 23) ||
        weekdays.keys.any((d) => d < 1 || d > 7) ||
        (returnRate ?? 0) > 1 ||
        (returned != null &&
            previousActive != null &&
            returned! > previousActive!)) {
      throw const FormatException('Invalid activity distribution');
    }
  }

  final int mau, totalMilliseconds;
  final int? guestMau, previousActive, returned;
  final double avgDau;
  final double? activeMinutes, returnRate;
  final Map<DateTime, int> daily;
  final Map<int, double> hours, weekdays;
  final Map<String, ReportSection> sections;
  final Map<DateTime, Map<String, ReportSection>> dailySections;
}

class ReportSection {
  ReportSection(Map<String, dynamic> json)
    : visitors = _count(json['visitors']),
      milliseconds = _count(json['milliseconds']);
  final int visitors, milliseconds;
  double get minutes => milliseconds / Duration.millisecondsPerMinute;
}

class ReportFirstWeek {
  ReportFirstWeek(Map<String, dynamic> json)
    : eligible = _count(json['eligible']),
      acted = _count(json['acted']),
      overEightMinutes = _count(json['overEightMinutes']),
      actions = _counts(json['actions']) {
    if (acted > eligible || overEightMinutes > eligible) {
      throw const FormatException('Invalid first week totals');
    }
  }
  final int eligible, acted, overEightMinutes;
  final Map<String, int> actions;
}

class ReportPeak {
  ReportPeak(Map<String, dynamic> json)
    : count = _count(json['count']),
      at = _instant(json['at']);
  final int count;
  final DateTime at;
}

class ReportPeaks {
  ReportPeaks(Map<String, dynamic> json)
    : samples = _count(json['samples']),
      members = json['members'] == null
          ? null
          : ReportPeak(_object(json['members'])),
      guests = json['guests'] == null
          ? null
          : ReportPeak(_object(json['guests']));
  final ReportPeak? members, guests;
  final int samples;
}
