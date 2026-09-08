import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/event/data/event_discovery_search_repository_impl.dart';

import 'support/recording_api_client.dart';

void main() {
  final date = DateTime(2026, 9, 7, 23, 30);

  test(
    'search combines chosen calendar day and full location on server',
    () async {
      final api = RecordingApiClient((_) => _page());
      final result = await EventDiscoverySearchRepositoryImpl(api).search(
        date: date,
        cityId: ' city ',
        districtId: ' district ',
        neighborhoodId: ' neighborhood ',
      );
      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.method, RecordedHttpMethod.get);
      expect(api.lastRequest.path, '/api/v1/events/discovery');
      expect(api.lastRequest.query, {
        'date': '2026-09-07',
        'cityId': 'city',
        'districtId': 'district',
        'neighborhoodId': 'neighborhood',
        'page': 0,
        'size': 20,
      });
      expect(isPublicApiRequest('GET', api.lastRequest.path), isTrue);
      expect(result.data!.content.single.title, 'Canlı müzik');
      expect(result.data!.content.single.startTime!.hour, 20);
      expect(result.data!.content.single.endTime!.minute, 30);
      expect(result.data!.content.single.bandId, 'band');
      expect(() => result.data!.content.clear(), throwsUnsupportedError);
    },
  );

  test('blank optional filters are omitted', () async {
    final api = RecordingApiClient((_) => _page());
    final result = await EventDiscoverySearchRepositoryImpl(
      api,
    ).search(date: date, cityId: 'city', districtId: ' ', neighborhoodId: '');
    expect(result.isSuccess, isTrue);
    expect(api.lastRequest.query!.keys, ['date', 'cityId', 'page', 'size']);
  });

  for (final spec in [
    (page: 0, size: 20, total: 0),
    (page: 0, size: 20, total: 41),
    (page: 1, size: 20, total: 41),
    (page: 2, size: 20, total: 41),
    (page: 5, size: 20, total: 0),
    (page: 5, size: 20, total: 41),
    (page: 1000, size: 50, total: 0),
    (page: 0, size: 1, total: 1),
    (page: 0, size: 20, total: 10000),
    (page: 250, size: 20, total: 10000),
    (page: 499, size: 20, total: 10000),
  ]) {
    test('decodes pagination $spec', () async {
      final api = RecordingApiClient(
        (_) => _page(page: spec.page, size: spec.size, total: spec.total),
      );
      final result = await EventDiscoverySearchRepositoryImpl(
        api,
      ).search(date: date, cityId: 'city', page: spec.page, size: spec.size);
      expect(result.isSuccess, isTrue);
      final data = result.data!;
      expect(data.number, spec.page);
      expect(data.size, spec.size);
      expect(data.totalElements, spec.total);
      expect(data.totalPages, (spec.total / spec.size).ceil());
      expect(data.last, spec.page + 1 >= data.totalPages);
      expect(
        data.content.length,
        (spec.total - spec.page * spec.size).clamp(0, spec.size),
      );
      expect(data.content.length, lessThanOrEqualTo(spec.size));
    });
  }

  for (final invalid in [
    'blank city',
    'neighborhood without district',
    'negative page',
    'excess page',
    'zero size',
    'excess size',
    'negative year',
  ]) {
    test('invalid $invalid does not send a request', () async {
      final api = RecordingApiClient((_) => _page());
      final result = await EventDiscoverySearchRepositoryImpl(api).search(
        date: invalid == 'negative year' ? DateTime(-1) : date,
        cityId: invalid == 'blank city' ? ' ' : 'city',
        neighborhoodId: invalid == 'neighborhood without district' ? 'n' : null,
        page: switch (invalid) {
          'negative page' => -1,
          'excess page' => 1001,
          _ => 0,
        },
        size: switch (invalid) {
          'zero size' => 0,
          'excess size' => 51,
          _ => 20,
        },
      );
      expect(result.error!.code, 'event_discovery_invalid_query');
      expect(api.requests, isEmpty);
    });
  }

  test('null optional fields and manual performer remain supported', () async {
    final response = _page();
    final item = (response['content'] as List).single as Map<String, dynamic>;
    item.addAll({
      'performerType': null,
      'bandId': null,
      'performerName': 'Belirtilmemiş',
      'bandMembers': null,
      'endTime': null,
    });
    final api = RecordingApiClient((_) => response);
    final result = await EventDiscoverySearchRepositoryImpl(
      api,
    ).search(date: date, cityId: 'city');
    expect(result.isSuccess, isTrue);
    expect(result.data!.content.single.performerType, 'MANUAL');
    expect(result.data!.content.single.bandId, isNull);
    expect(result.data!.content.single.bandMembers, isEmpty);
    expect(result.data!.content.single.posterImageUrl, isNull);
  });

  test('inconsistent performer identity stays non-navigable', () async {
    final response = _page();
    response['content'][0]['musicianProfileId'] = 'musician';
    final api = RecordingApiClient((_) => response);
    final result = await EventDiscoverySearchRepositoryImpl(
      api,
    ).search(date: date, cityId: 'city');
    expect(result.isSuccess, isTrue);
    expect(result.data!.content.single.bandId, isNull);
    expect(result.data!.content.single.musicianProfileId, isNull);
  });

  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'missing content': (json) => json.remove('content'),
    'nonlist content': (json) => json['content'] = {},
    'missing row': (json) => json['content'] = [],
    'nonmap row': (json) => json['content'] = [42],
    'duplicate row': (json) {
      json['content'] = [_row(), _row()];
      json['totalElements'] = 2;
    },
    'string number': (json) => json['number'] = '0',
    'wrong number': (json) => json['number'] = 1,
    'wrong size': (json) => json['size'] = 50,
    'negative total': (json) => json['totalElements'] = -1,
    'wrong total pages': (json) => json['totalPages'] = 2,
    'wrong last': (json) => json['last'] = false,
    'string last': (json) => json['last'] = 'true',
    'blank identity': (json) => json['content'][0]['id'] = ' ',
    'numeric title': (json) => json['content'][0]['title'] = 42,
    'missing venue': (json) => json['content'][0]['venueId'] = null,
    'wrong date': (json) => json['content'][0]['eventDate'] = '2026-09-08',
    'invalid date': (json) => json['content'][0]['eventDate'] = '2026-02-30',
    'missing start': (json) => json['content'][0]['startTime'] = null,
    'hour overflow': (json) => json['content'][0]['startTime'] = '25:00',
    'minute overflow': (json) => json['content'][0]['startTime'] = '20:60',
    'second overflow': (json) => json['content'][0]['endTime'] = '22:00:60',
    'wrong image type': (json) => json['content'][0]['posterImage'] = [],
    'wrong optional type': (json) => json['content'][0]['description'] = {},
    'wrong members type': (json) => json['content'][0]['bandMembers'] = {},
    'wrong member type': (json) => json['content'][0]['bandMembers'] = [1],
  }.entries) {
    test('rejects malformed response: ${mutation.key}', () async {
      final response = _page();
      mutation.value(response);
      final api = RecordingApiClient((_) => response);
      final result = await EventDiscoverySearchRepositoryImpl(
        api,
      ).search(date: date, cityId: 'city');
      expect(result.error?.code, 'event_discovery_malformed_response');
      expect(result.data, isNull);
    });
  }

  for (final payload in <Object?>[null, [], 'invalid', 1]) {
    test('nonobject page $payload is not converted to empty results', () async {
      final api = RecordingApiClient((_) => payload);
      final result = await EventDiscoverySearchRepositoryImpl(
        api,
      ).search(date: date, cityId: 'city');
      expect(result.error?.code, 'event_discovery_malformed_response');
    });
  }

  test('API error preserves server date-window validation', () async {
    const error = AppError(
      code: '400',
      message: 'Bu tarih için arama yapılamaz.',
    );
    final api = RecordingApiClient((_) => throw ApiException(error));
    final result = await EventDiscoverySearchRepositoryImpl(
      api,
    ).search(date: date, cityId: 'city');
    expect(result.error, same(error));
  });

  test('unexpected transport error is recoverable and localized', () async {
    final api = RecordingApiClient((_) => throw StateError('offline'));
    final result = await EventDiscoverySearchRepositoryImpl(
      api,
    ).search(date: date, cityId: 'city');
    expect(result.error?.code, 'event_discovery_failed');
    expect(result.error?.message, contains('yeniden dene'));
  });

  test(
    'network timeout exposes friendly copy without origin or debug advice',
    () async {
      const error = AppError(
        code: 'network',
        message:
            'Baglanti zaman asimi: https://api.internal.example. '
            'Backend/Ag/Firewall kontrol et.',
        details: ['retryable'],
      );
      final api = RecordingApiClient((_) => throw ApiException(error));
      final result = await EventDiscoverySearchRepositoryImpl(
        api,
      ).search(date: date, cityId: 'city');
      expect(result.error?.code, 'network');
      expect(result.error?.details, same(error.details));
      expect(
        result.error?.message,
        'Etkinlikler yüklenemedi. İnternet bağlantını kontrol edip yeniden dene.',
      );
      expect(result.error?.message, isNot(contains('api.internal.example')));
      expect(result.error?.message, isNot(contains('Backend')));
      expect(result.error?.message, isNot(contains('Firewall')));
    },
  );
}

Map<String, dynamic> _row() => {
  'id': 'event',
  'title': 'Canlı müzik',
  'performerName': 'Şahbaz',
  'performerType': 'BAND',
  'musicianProfileId': null,
  'bandId': 'band',
  'bandMembers': ['bugrasahin', 'aedrum'],
  'venueId': 'venue',
  'venueName': 'SoundConnect Ankara',
  'venueCity': 'Ankara',
  'venueDistrict': 'Çankaya',
  'venueNeighborhood': null,
  'eventDate': '2026-09-07',
  'startTime': '20:00:00',
  'endTime': '22:30:00.123456789',
  'posterImage': null,
  'description': 'Kısa etkinlik notu',
};

Map<String, dynamic> _page({int page = 0, int size = 20, int total = 1}) => {
  'content': [
    for (var i = 0; i < (total - page * size).clamp(0, size); i++)
      _row()..['id'] = 'event-$i',
  ],
  'number': page,
  'size': size,
  'totalElements': total,
  'totalPages': (total / size).ceil(),
  'last': page + 1 >= (total / size).ceil(),
};
