const _months = [
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
const eventPlanWeekdayNames = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String eventPlanDateLabel(DateTime date, {bool includeWeekday = true}) {
  final label = '${date.day} ${_months[date.month - 1]} ${date.year}';
  return includeWeekday
      ? '$label ${eventPlanWeekdayNames[date.weekday - 1]}'
      : label;
}
