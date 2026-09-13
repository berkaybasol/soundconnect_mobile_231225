import 'announcement.dart';
import 'announcement.dart' as validation;

class AnnouncementStatistics {
  const AnnouncementStatistics({
    required this.announcementId,
    required this.fromDate,
    required this.toDate,
    required this.updatedAt,
    required this.metrics,
    required this.daily,
  });
  final String announcementId;
  final String fromDate;
  final String toDate;
  final DateTime updatedAt;
  final Map<String, int> metrics;
  final List<({String date, Map<String, int> metrics})> daily;
  static const metricLabels = <String, String>{
    'impressions': 'Gösterim',
    'uniqueReach': 'Tekil erişim',
    'detailViews': 'Detay görüntüleme',
    'videoStarts': 'Video başlatma',
    'videoCompletions': 'Video tamamlama',
    'likes': 'Beğeni',
    'comments': 'Yorum',
    'hiders': 'Gizleyen',
  };
  factory AnnouncementStatistics.fromJson(Object? value) {
    final json = announcementObject(value);
    Map<String, int> metrics(Object? raw) {
      final data = announcementObject(raw);
      return Map.unmodifiable({
        for (final key in metricLabels.keys) key: announcementCount(data[key]),
      });
    }

    String date(Object? raw) {
      if (raw is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ||
          DateTime.tryParse(raw) == null) {
        throw const FormatException('Invalid statistics date');
      }
      return raw;
    }

    final rows = json['daily'];
    if (json['timeZone'] != 'Europe/Istanbul' ||
        rows is! List ||
        rows.length > 366) {
      throw const FormatException('Invalid statistics range');
    }
    return AnnouncementStatistics(
      announcementId: validation.announcementId(json['announcementId']),
      fromDate: date(json['fromDate']),
      toDate: date(json['toDate']),
      updatedAt:
          announcementDate(json['updatedAt']) ??
          (throw const FormatException('Missing statistics freshness')),
      metrics: metrics(json['metrics']),
      daily: List.unmodifiable(
        rows.map((row) {
          final item = announcementObject(row);
          return (date: date(item['date']), metrics: metrics(item['metrics']));
        }),
      ),
    );
  }
}
