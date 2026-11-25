import '../../../../core/utils/turkish_date_label.dart';

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
  final label = turkishDateLabel(date);
  return includeWeekday
      ? '$label ${eventPlanWeekdayNames[date.weekday - 1]}'
      : label;
}
