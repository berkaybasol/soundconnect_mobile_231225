import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/venue_analytics_repository.dart';

class VenueAnalyticsRepositoryImpl implements VenueAnalyticsRepository {
  VenueAnalyticsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<VenueAnalyticsSummary>> summary({
    required String venueId,
    required String expectedSessionKey,
    int days = 30,
  }) => _summary(venueId, expectedSessionKey, days, null);

  @override
  Future<Result<VenueAnalyticsSummary>> event({
    required String venueId,
    required String eventId,
    required String expectedSessionKey,
    int days = 30,
  }) => _summary(venueId, expectedSessionKey, days, eventId);

  Future<Result<VenueAnalyticsSummary>> _summary(
    String venueId,
    String key,
    int days,
    String? eventId,
  ) => _read(() async {
    _validate(venueId, key, days);
    if (eventId != null && eventId.trim().isEmpty) {
      throw const FormatException();
    }
    final result = await _api.request<VenueAnalyticsSummary>(
      ApiHttpMethod.get,
      '/api/v1/venue-analytics/${Uri.encodeComponent(venueId.trim())}${eventId == null ? '' : '/events/${Uri.encodeComponent(eventId.trim())}'}',
      query: {'days': days},
      requestContext: ApiRequestContext(expectedSessionKey: key.trim()),
      decoder: _decodeSummary,
    );
    if (result.venueId != venueId.trim() ||
        result.eventId != eventId?.trim() ||
        result.days != days) {
      throw const FormatException('Analytics scope mismatch');
    }
    return result;
  });

  @override
  Future<Result<VenueAnalyticsEventPage>> events({
    required String venueId,
    required String expectedSessionKey,
    int days = 30,
    int page = 0,
    int size = 20,
    VenueAnalyticsSort sort = VenueAnalyticsSort.date,
  }) => _read(() async {
    _validate(venueId, expectedSessionKey, days);
    if (page < 0 || page > 1000 || size < 1 || size > 50) {
      throw const FormatException();
    }
    final result = await _api.request<VenueAnalyticsEventPage>(
      ApiHttpMethod.get,
      '/api/v1/venue-analytics/${Uri.encodeComponent(venueId.trim())}/events',
      query: {'days': days, 'page': page, 'size': size, 'sort': sort.apiValue},
      requestContext: ApiRequestContext(
        expectedSessionKey: expectedSessionKey.trim(),
      ),
      decoder: _decodePage,
    );
    if (result.page != page || result.size != size || result.sort != sort) {
      throw const FormatException('Analytics page mismatch');
    }
    return result;
  });

  static Future<Result<T>> _read<T>(Future<T> Function() operation) async {
    try {
      return Result.success(await operation());
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'venue_analytics_unavailable',
          message: 'İstatistikler şu anda yüklenemiyor. Yeniden dene.',
        ),
      );
    }
  }

  static void _validate(String venueId, String key, int days) {
    if (venueId.trim().isEmpty ||
        key.trim().isEmpty ||
        ![7, 30, 90].contains(days)) {
      throw const FormatException('Invalid analytics request');
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid object');
    }
    return value;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid text');
    }
    return value.trim();
  }

  static int _integer(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid count');
    }
    return value;
  }

  static DateTime _date(Object? value) {
    final text = _text(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const FormatException('Invalid date');
    }
    final date = DateTime.tryParse(text);
    if (date == null || date.toIso8601String().substring(0, 10) != text) {
      throw const FormatException('Invalid date');
    }
    return DateTime.utc(date.year, date.month, date.day);
  }

  static DateTime _instant(Object? value) {
    final text = _text(value);
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
      throw const FormatException('Missing timezone');
    }
    final date = DateTime.tryParse(text);
    if (date == null) throw const FormatException('Invalid instant');
    return date;
  }

  static VenueAnalyticsMetrics _metrics(Object? value) {
    final json = _map(value);
    return VenueAnalyticsMetrics(
      impressions: _integer(json['impressions']),
      detailViews: _integer(json['detailViews']),
      profileVisits: _integer(json['profileVisits']),
    );
  }

  static VenueAnalyticsSummary _decodeSummary(Object? value) {
    final json = _map(value);
    final from = _date(json['fromDate']);
    final to = _date(json['toDate']);
    final days = _integer(json['days']);
    final zone = _text(json['timeZone']);
    final started = json['trackingStartedAt'] == null
        ? null
        : _instant(json['trackingStartedAt']);
    final updated = _instant(json['updatedAt']);
    if (![7, 30, 90].contains(days) ||
        to.difference(from).inDays != days - 1 ||
        zone != 'Europe/Istanbul' ||
        _istanbulDay(updated) != to ||
        (started != null && started.isAfter(updated))) {
      throw const FormatException('Invalid period');
    }
    return VenueAnalyticsSummary(
      venueId: _text(json['venueId']),
      eventId: json['eventId'] == null ? null : _text(json['eventId']),
      fromDate: from,
      toDate: to,
      days: days,
      timeZone: zone,
      trackingStartedAt: started,
      updatedAt: updated,
      metrics: _metrics(json['metrics']),
      daily: json.containsKey('daily')
          ? _daily(json['daily'], from, to, days, started)
          : const [],
      comparison: json.containsKey('comparison')
          ? _comparison(json['comparison'], to, days, started)
          : null,
    );
  }

  static DateTime _istanbulDay(DateTime instant) {
    final local = instant.toUtc().add(const Duration(hours: 3));
    return DateTime.utc(local.year, local.month, local.day);
  }

  static List<VenueAnalyticsDailyPoint> _daily(
    Object? value,
    DateTime from,
    DateTime to,
    int days,
    DateTime? started,
  ) {
    if (value is! List || value.length != days) {
      throw const FormatException('Invalid daily coverage');
    }
    final startDay = started == null ? null : _istanbulDay(started);
    return List.unmodifiable(
      List.generate(days, (index) {
        final item = _map(value[index]);
        final date = _date(item['date']);
        final expected = from.add(Duration(days: index));
        final actual = item['metrics'] != null;
        final covered = startDay != null && !date.isBefore(startDay);
        final earlyFact = startDay != null && date.isBefore(startDay) && actual;
        final partial =
            date == to ||
            earlyFact ||
            (date == startDay &&
                started!.isAfter(date.subtract(const Duration(hours: 3))));
        if (date != expected ||
            item['partial'] is! bool ||
            item['partial'] != partial ||
            !item.containsKey('metrics') ||
            (covered && !actual) ||
            (started == null && actual)) {
          throw const FormatException('Invalid daily point');
        }
        return VenueAnalyticsDailyPoint(
          date: date,
          metrics: actual ? _metrics(item['metrics']) : null,
          partial: partial,
        );
      }),
    );
  }

  static VenueAnalyticsComparison _comparison(
    Object? value,
    DateTime today,
    int days,
    DateTime? started,
  ) {
    final item = _map(value);
    final currentTo = today.subtract(const Duration(days: 1));
    final currentFrom = today.subtract(Duration(days: days));
    final previousTo = currentFrom.subtract(const Duration(days: 1));
    final previousFrom = currentFrom.subtract(Duration(days: days));
    final status = switch (item['status']) {
      'AVAILABLE' => VenueAnalyticsComparisonStatus.available,
      'NOT_STARTED' => VenueAnalyticsComparisonStatus.notStarted,
      'INSUFFICIENT_HISTORY' =>
        VenueAnalyticsComparisonStatus.insufficientHistory,
      'RETENTION_LIMIT' => VenueAnalyticsComparisonStatus.retentionLimit,
      _ => throw const FormatException('Invalid comparison status'),
    };
    final expectedStatus = started == null
        ? VenueAnalyticsComparisonStatus.notStarted
        : previousFrom.isBefore(today.subtract(const Duration(days: 89)))
        ? VenueAnalyticsComparisonStatus.retentionLimit
        : started.isAfter(previousFrom.subtract(const Duration(hours: 3)))
        ? VenueAnalyticsComparisonStatus.insufficientHistory
        : VenueAnalyticsComparisonStatus.available;
    final available = status == VenueAnalyticsComparisonStatus.available;
    if (status != expectedStatus ||
        _date(item['currentFromDate']) != currentFrom ||
        _date(item['currentToDate']) != currentTo ||
        _date(item['previousFromDate']) != previousFrom ||
        _date(item['previousToDate']) != previousTo ||
        !item.containsKey('currentMetrics') ||
        !item.containsKey('previousMetrics') ||
        (item['currentMetrics'] != null) != available ||
        (item['previousMetrics'] != null) != available) {
      throw const FormatException('Invalid comparison coverage');
    }
    return VenueAnalyticsComparison(
      status: status,
      currentFromDate: currentFrom,
      currentToDate: currentTo,
      previousFromDate: previousFrom,
      previousToDate: previousTo,
      currentMetrics: available ? _metrics(item['currentMetrics']) : null,
      previousMetrics: available ? _metrics(item['previousMetrics']) : null,
    );
  }

  static VenueAnalyticsEventPage _decodePage(Object? value) {
    final json = _map(value);
    final page = _integer(json['page']);
    final size = _integer(json['size']);
    final total = _integer(json['totalElements']);
    final pages = _integer(json['totalPages']);
    final hasNext = json['hasNext'];
    final raw = json['content'];
    final sort = json.containsKey('sort')
        ? VenueAnalyticsSort.values.firstWhere(
            (candidate) => candidate.apiValue == json['sort'],
            orElse: () => throw const FormatException('Invalid event sort'),
          )
        : VenueAnalyticsSort.date;
    if (size < 1 ||
        size > 50 ||
        page > 1000 ||
        hasNext is! bool ||
        raw is! List ||
        raw.length > size ||
        raw.length != (total - page * size).clamp(0, size) ||
        pages != (total / size).ceil() ||
        hasNext != (page + 1 < pages)) {
      throw const FormatException('Invalid page');
    }
    final ids = <String>{};
    final items = raw
        .map((item) {
          final data = _map(item);
          final id = _text(data['eventId']);
          if (!ids.add(id)) throw const FormatException('Duplicate event');
          return VenueAnalyticsEvent(
            eventId: id,
            title: _text(data['title']),
            eventDate: _date(data['eventDate']),
            metrics: _metrics(data['metrics']),
          );
        })
        .toList(growable: false);
    return VenueAnalyticsEventPage(
      items: List.unmodifiable(items),
      page: page,
      size: size,
      totalElements: total,
      totalPages: pages,
      hasNext: hasNext,
      sort: sort,
    );
  }
}
