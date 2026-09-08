import '../../../core/error/result.dart';

enum VenueAnalyticsSort {
  date('DATE'),
  reach('REACH'),
  detailViews('DETAIL_VIEWS'),
  profileVisits('PROFILE_VISITS');

  const VenueAnalyticsSort(this.apiValue);
  final String apiValue;
}

enum VenueAnalyticsComparisonStatus {
  available,
  notStarted,
  insufficientHistory,
  retentionLimit,
}

class VenueAnalyticsDailyPoint {
  const VenueAnalyticsDailyPoint({
    required this.date,
    required this.metrics,
    required this.partial,
  });
  final DateTime date;
  final VenueAnalyticsMetrics? metrics;
  final bool partial;
}

class VenueAnalyticsComparison {
  const VenueAnalyticsComparison({
    required this.status,
    required this.currentFromDate,
    required this.currentToDate,
    required this.previousFromDate,
    required this.previousToDate,
    this.currentMetrics,
    this.previousMetrics,
  });
  final VenueAnalyticsComparisonStatus status;
  final DateTime currentFromDate;
  final DateTime currentToDate;
  final DateTime previousFromDate;
  final DateTime previousToDate;
  final VenueAnalyticsMetrics? currentMetrics;
  final VenueAnalyticsMetrics? previousMetrics;
}

class VenueAnalyticsMetrics {
  const VenueAnalyticsMetrics({
    required this.impressions,
    required this.detailViews,
    required this.profileVisits,
  });
  final int impressions;
  final int detailViews;
  final int profileVisits;
}

class VenueAnalyticsSummary {
  const VenueAnalyticsSummary({
    required this.venueId,
    this.eventId,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.timeZone,
    required this.trackingStartedAt,
    required this.updatedAt,
    required this.metrics,
    this.daily = const [],
    this.comparison,
  });
  final String venueId;
  final String? eventId;
  final DateTime fromDate;
  final DateTime toDate;
  final int days;
  final String timeZone;
  final DateTime? trackingStartedAt;
  final DateTime updatedAt;
  final VenueAnalyticsMetrics metrics;
  final List<VenueAnalyticsDailyPoint> daily;
  final VenueAnalyticsComparison? comparison;
}

class VenueAnalyticsEvent {
  const VenueAnalyticsEvent({
    required this.eventId,
    required this.title,
    required this.eventDate,
    required this.metrics,
  });
  final String eventId;
  final String title;
  final DateTime eventDate;
  final VenueAnalyticsMetrics metrics;
}

class VenueAnalyticsEventPage {
  const VenueAnalyticsEventPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
    this.sort = VenueAnalyticsSort.date,
  });
  final List<VenueAnalyticsEvent> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final VenueAnalyticsSort sort;
}

abstract class VenueAnalyticsRepository {
  Future<Result<VenueAnalyticsSummary>> summary({
    required String venueId,
    required String expectedSessionKey,
    int days = 30,
  });
  Future<Result<VenueAnalyticsSummary>> event({
    required String venueId,
    required String eventId,
    required String expectedSessionKey,
    int days = 30,
  });
  Future<Result<VenueAnalyticsEventPage>> events({
    required String venueId,
    required String expectedSessionKey,
    int days = 30,
    int page = 0,
    int size = 20,
    VenueAnalyticsSort sort = VenueAnalyticsSort.date,
  });
}
