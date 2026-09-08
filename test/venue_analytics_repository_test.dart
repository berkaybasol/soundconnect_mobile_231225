import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/venue_analytics_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/venue_analytics_repository.dart';

void main() {
  test(
    'summary uses private scope with captured session fence and exact period',
    () async {
      final api = _Api()..response = _summary();
      final result = await VenueAnalyticsRepositoryImpl(
        api,
      ).summary(venueId: 'venue', expectedSessionKey: 'owner');
      expect(result.isSuccess, isTrue);
      expect(result.data!.metrics.impressions, 1200);
      expect(api.path, '/api/v1/venue-analytics/venue');
      expect(api.query, {'days': 30});
      expect(api.context!.expectedSessionKey, 'owner');
      expect(api.method, ApiHttpMethod.get);
    },
  );
  test(
    'event path is encoded and validates event and venue identity',
    () async {
      final api = _Api()..response = {..._summary(), 'eventId': 'event/id'};
      final result = await VenueAnalyticsRepositoryImpl(api).event(
        venueId: 'venue',
        eventId: 'event/id',
        expectedSessionKey: 'owner',
      );
      expect(result.isSuccess, isTrue);
      expect(api.path, '/api/v1/venue-analytics/venue/events/event%2Fid');
    },
  );
  for (final field in ['venueId', 'eventId', 'days']) {
    test('summary rejects mismatched $field', () async {
      final api = _Api()
        ..response = {..._summary(), field: field == 'days' ? 7 : 'another'};
      final result = await VenueAnalyticsRepositoryImpl(
        api,
      ).summary(venueId: 'venue', expectedSessionKey: 'owner');
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
    });
  }
  for (final change in [
    {
      'metrics': {'impressions': -1, 'detailViews': 1, 'profileVisits': 1},
    },
    {
      'metrics': {'impressions': '12', 'detailViews': 1, 'profileVisits': 1},
    },
    {
      'metrics': {'impressions': 1.5, 'detailViews': 1, 'profileVisits': 1},
    },
    {'metrics': <String, dynamic>{}},
    {'fromDate': '2026-02-30'},
    {'timeZone': 'UTC'},
    {'updatedAt': 'yesterday'},
    {'trackingStartedAt': '2026-09-08T12:00:00'},
  ]) {
    test('rejects malformed metrics or date metadata $change', () async {
      final api = _Api()..response = {..._summary(), ...change};
      expect(
        (await VenueAnalyticsRepositoryImpl(
          api,
        ).summary(venueId: 'venue', expectedSessionKey: 'owner')).isSuccess,
        isFalse,
      );
    });
  }
  for (final request in [
    ('venue', '', 30),
    ('', 'owner', 30),
    ('venue', 'owner', 8),
  ]) {
    test('invalid request $request performs no network operation', () async {
      final api = _Api();
      expect(
        (await VenueAnalyticsRepositoryImpl(api).summary(
          venueId: request.$1,
          expectedSessionKey: request.$2,
          days: request.$3,
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, 0);
    });
  }
  test('zero is real data and a missing tracking start stays null', () async {
    final api = _Api()
      ..response = {
        ..._summary(),
        'trackingStartedAt': null,
        'metrics': {'impressions': 0, 'detailViews': 0, 'profileVisits': 0},
      };
    final result = await VenueAnalyticsRepositoryImpl(
      api,
    ).summary(venueId: 'venue', expectedSessionKey: 'owner');
    expect(result.data!.trackingStartedAt, isNull);
    expect(result.data!.metrics.profileVisits, 0);
  });
  test(
    'paged events are one fenced request with complete row metrics',
    () async {
      final api = _Api()..response = _page();
      final result = await VenueAnalyticsRepositoryImpl(
        api,
      ).events(venueId: 'venue', expectedSessionKey: 'owner', days: 7);
      expect(result.isSuccess, isTrue);
      expect(result.data!.items.single.metrics.detailViews, 500);
      expect(api.calls, 1);
      expect(api.query, {'days': 7, 'page': 0, 'size': 20, 'sort': 'DATE'});
      expect(api.context!.expectedSessionKey, 'owner');
    },
  );
  for (final change in [
    {'page': 1},
    {'size': 10},
    {'hasNext': true},
    {'totalPages': 2},
    {'content': <Object>[]},
    {
      'content': [_row(), _row()],
    },
  ]) {
    test(
      'rejects mismatched pagination or duplicate event ids $change',
      () async {
        final api = _Api()..response = {..._page(), ...change};
        expect(
          (await VenueAnalyticsRepositoryImpl(
            api,
          ).events(venueId: 'venue', expectedSessionKey: 'owner')).isSuccess,
          isFalse,
        );
      },
    );
  }
  test('transport exceptions never become zero-valued successes', () async {
    final api = _Api()..fail = true;
    final result = await VenueAnalyticsRepositoryImpl(
      api,
    ).summary(venueId: 'venue', expectedSessionKey: 'owner');
    expect(result.isSuccess, isFalse);
    expect(result.data, isNull);
  });
  test('pages beyond the backend 1000 limit never dispatch', () async {
    final api = _Api();
    final result = await VenueAnalyticsRepositoryImpl(
      api,
    ).events(venueId: 'venue', expectedSessionKey: 'owner', page: 1001);
    expect(result.isSuccess, isFalse);
    expect(api.calls, 0);
  });

  for (final days in [7, 30, 90]) {
    test(
      'daily coverage and complete-day comparison decode for $days days',
      () async {
        final api = _Api()..response = _report(days: days);
        final result = await VenueAnalyticsRepositoryImpl(
          api,
        ).summary(venueId: 'venue', expectedSessionKey: 'owner', days: days);
        expect(result.isSuccess, isTrue);
        final summary = result.data!;
        expect(summary.daily.length, days);
        expect(summary.daily.last.partial, isTrue);
        expect(summary.daily.first.partial, isFalse);
        expect(summary.comparison!.currentToDate, DateTime.utc(2026, 9, 7));
        expect(
          summary.comparison!.status,
          days == 90
              ? VenueAnalyticsComparisonStatus.retentionLimit
              : VenueAnalyticsComparisonStatus.available,
        );
        expect(
          summary.comparison!.currentMetrics?.impressions,
          days == 90 ? isNull : 1200,
        );
      },
    );
  }
  test('legacy fields stay unavailable without fabricated history', () async {
    final api = _Api()..response = _summary();
    final result = await VenueAnalyticsRepositoryImpl(
      api,
    ).summary(venueId: 'venue', expectedSessionKey: 'owner');
    expect(result.data!.daily, isEmpty);
    expect(result.data!.comparison, isNull);
  });
  test(
    'unknown days remain null and delayed actual pre-start facts are partial',
    () async {
      final report = _report(started: DateTime.utc(2026, 9, 8, 8));
      final daily = report['daily'] as List<Map<String, dynamic>>;
      daily[daily.length - 2]['metrics'] = _summary()['metrics'];
      daily[daily.length - 2]['partial'] = true;
      final api = _Api()..response = report;
      final result = await VenueAnalyticsRepositoryImpl(
        api,
      ).summary(venueId: 'venue', expectedSessionKey: 'owner');
      expect(result.isSuccess, isTrue);
      expect(result.data!.daily.first.metrics, isNull);
      expect(result.data!.daily[28].metrics!.impressions, 1200);
      expect(result.data!.daily[28].partial, isTrue);
      expect(
        result.data!.comparison!.status,
        VenueAnalyticsComparisonStatus.insufficientHistory,
      );
    },
  );
  test(
    'no collection has null daily values and not-started comparison even at 90',
    () async {
      final api = _Api()..response = _report(days: 90, notStarted: true);
      final result = await VenueAnalyticsRepositoryImpl(
        api,
      ).summary(venueId: 'venue', expectedSessionKey: 'owner', days: 90);
      expect(result.isSuccess, isTrue);
      expect(
        result.data!.daily.every((point) => point.metrics == null),
        isTrue,
      );
      expect(result.data!.daily.last.partial, isTrue);
      expect(
        result.data!.comparison!.status,
        VenueAnalyticsComparisonStatus.notStarted,
      );
    },
  );
  final invalidReports = <String, void Function(Map<String, dynamic>)>{
    'null daily': (report) => report['daily'] = null,
    'empty daily': (report) => report['daily'] = [],
    'duplicate date': (report) => (report['daily'] as List)[1]['date'] =
        (report['daily'] as List)[0]['date'],
    'shifted date': (report) =>
        (report['daily'] as List)[0]['date'] = '2026-08-09',
    'unknown covered day': (report) =>
        (report['daily'] as List)[0]['metrics'] = null,
    'bad daily count': (report) => (report['daily'] as List)[0]['metrics'] = {
      'impressions': -1,
      'detailViews': 0,
      'profileVisits': 0,
    },
    'string partial': (report) =>
        (report['daily'] as List)[0]['partial'] = 'false',
    'complete today': (report) =>
        (report['daily'] as List).last['partial'] = false,
    'null comparison': (report) => report['comparison'] = null,
    'unknown comparison status': (report) =>
        (report['comparison'] as Map)['status'] = 'NEW',
    'wrong comparison dates': (report) =>
        (report['comparison'] as Map)['currentToDate'] = '2026-09-08',
    'wrong previous dates': (report) =>
        (report['comparison'] as Map)['previousFromDate'] = '2026-07-11',
    'missing current comparison counts': (report) =>
        (report['comparison'] as Map)['currentMetrics'] = null,
    'missing previous comparison counts': (report) =>
        (report['comparison'] as Map)['previousMetrics'] = null,
    'false not-started': (report) =>
        (report['comparison'] as Map)['status'] = 'NOT_STARTED',
    'read day differs': (report) =>
        report['updatedAt'] = '2026-09-09T00:00:00Z',
  };
  for (final entry in invalidReports.entries) {
    test(
      'malformed present reporting field fails closed: ${entry.key}',
      () async {
        final report = _report();
        entry.value(report);
        final result = await VenueAnalyticsRepositoryImpl(
          _Api()..response = report,
        ).summary(venueId: 'venue', expectedSessionKey: 'owner');
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      },
    );
  }
  test('unavailable comparison cannot claim numeric results', () async {
    final report = _report(started: DateTime.utc(2026, 9, 8, 8));
    (report['comparison'] as Map)['currentMetrics'] = _summary()['metrics'];
    final result = await VenueAnalyticsRepositoryImpl(
      _Api()..response = report,
    ).summary(venueId: 'venue', expectedSessionKey: 'owner');
    expect(result.isSuccess, isFalse);
  });
  for (final sort in VenueAnalyticsSort.values) {
    test('event sort ${sort.apiValue} is server scoped and echoed', () async {
      final api = _Api()..response = {..._page(), 'sort': sort.apiValue};
      final result = await VenueAnalyticsRepositoryImpl(
        api,
      ).events(venueId: 'venue', expectedSessionKey: 'owner', sort: sort);
      expect(result.isSuccess, isTrue);
      expect(result.data!.sort, sort);
      expect(api.query!['sort'], sort.apiValue);
    });
  }
  for (final responseSort in ['DATE', 'wrong', null]) {
    test('unexpected event sort $responseSort fails', () async {
      final api = _Api()..response = {..._page(), 'sort': responseSort};
      final result = await VenueAnalyticsRepositoryImpl(api).events(
        venueId: 'venue',
        expectedSessionKey: 'owner',
        sort: VenueAnalyticsSort.reach,
      );
      expect(result.isSuccess, isFalse);
    });
  }
}

Map<String, dynamic> _report({
  int days = 30,
  DateTime? started,
  bool notStarted = false,
}) {
  started = notStarted ? null : started ?? DateTime.utc(2026, 6, 1);
  final today = DateTime.utc(2026, 9, 8);
  final from = today.subtract(Duration(days: days - 1));
  final currentFrom = today.subtract(Duration(days: days));
  final previousFrom = currentFrom.subtract(Duration(days: days));
  final startLocal = started?.add(const Duration(hours: 3));
  final startDay = startLocal == null
      ? null
      : DateTime.utc(startLocal.year, startLocal.month, startLocal.day);
  final status = started == null
      ? 'NOT_STARTED'
      : days == 90
      ? 'RETENTION_LIMIT'
      : started.isAfter(previousFrom.subtract(const Duration(hours: 3)))
      ? 'INSUFFICIENT_HISTORY'
      : 'AVAILABLE';
  String date(DateTime value) => value.toIso8601String().substring(0, 10);
  return {
    ..._summary(),
    'fromDate': date(from),
    'days': days,
    'trackingStartedAt': started?.toIso8601String(),
    'daily': List.generate(days, (index) {
      final point = from.add(Duration(days: index));
      return <String, dynamic>{
        'date': date(point),
        'metrics': startDay != null && !point.isBefore(startDay)
            ? _summary()['metrics']
            : null,
        'partial':
            point == today ||
            (point == startDay &&
                started!.isAfter(point.subtract(const Duration(hours: 3)))),
      };
    }),
    'comparison': {
      'status': status,
      'currentFromDate': date(currentFrom),
      'currentToDate': '2026-09-07',
      'previousFromDate': date(previousFrom),
      'previousToDate': date(currentFrom.subtract(const Duration(days: 1))),
      'currentMetrics': status == 'AVAILABLE' ? _summary()['metrics'] : null,
      'previousMetrics': status == 'AVAILABLE' ? _summary()['metrics'] : null,
    },
  };
}

Map<String, dynamic> _summary() => {
  'venueId': 'venue',
  'fromDate': '2026-08-10',
  'toDate': '2026-09-08',
  'days': 30,
  'timeZone': 'Europe/Istanbul',
  'trackingStartedAt': '2026-09-08T09:00:00Z',
  'updatedAt': '2026-09-08T12:00:00Z',
  'metrics': {'impressions': 1200, 'detailViews': 500, 'profileVisits': 42},
};
Map<String, dynamic> _row() => {
  'eventId': 'event',
  'title': 'Canlı müzik akşamı',
  'eventDate': '2026-09-08',
  'metrics': _summary()['metrics'],
};
Map<String, dynamic> _page() => {
  'content': [_row()],
  'page': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'hasNext': false,
};

class _Api extends Fake implements ApiClient {
  Object? response;
  bool fail = false;
  int calls = 0;
  String? path;
  Map<String, dynamic>? query;
  ApiRequestContext? context;
  ApiHttpMethod? method;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.query = query;
    context = requestContext;
    if (fail) throw StateError('Unavailable');
    return decoder!(response);
  }
}
