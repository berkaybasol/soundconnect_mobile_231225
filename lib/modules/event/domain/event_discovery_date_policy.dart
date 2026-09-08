/// Calendar dates in discovery use Istanbul's current UTC+03 region, not the
/// device timezone. Date-only values below carry calendar fields, not instants.
abstract final class EventDiscoveryDatePolicy {
  static const int dayCount = 7;
  static const _istanbulOffset = Duration(hours: 3);

  static const _shortMonths = <String>[
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  static const _months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  static const _weekdays = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static DateTime today([DateTime? now]) {
    final regionalTime = (now ?? DateTime.now()).toUtc().add(_istanbulOffset);
    return normalizeDate(regionalTime);
  }

  /// Intentionally does not convert timezone: [date] is already a chosen day.
  static DateTime normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool contains(DateTime date, DateTime today) {
    // UTC field-only comparison avoids 23/25-hour DST days on a foreign device.
    final day = DateTime.utc(date.year, date.month, date.day);
    final first = DateTime.utc(today.year, today.month, today.day);
    final difference = day.difference(first).inDays;
    return difference >= 0 && difference < dayCount;
  }

  static String apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String shortDate(DateTime date) =>
      '${date.day} ${_shortMonths[date.month - 1]}';

  static String longDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];
}
