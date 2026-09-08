import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_collection_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/analytics_observation.dart';

const _clientId = '00000000-0000-4000-8000-000000000001';
const _eventId = '00000000-0000-4000-8000-000000000002';
const _venueId = '00000000-0000-4000-8000-000000000003';
const _observationId = '00000000-0000-4000-8000-000000000004';

AnalyticsObservation _observation({
  AnalyticsObservationType type = AnalyticsObservationType.eventImpression,
  String id = _observationId,
}) => AnalyticsObservation(
  id: id,
  type: type,
  observedAt: DateTime.utc(2026, 9, 8, 10),
  eventId: type == AnalyticsObservationType.venueProfileView ? null : _eventId,
  venueId: type == AnalyticsObservationType.venueProfileView ? _venueId : null,
  sourceEventId: type == AnalyticsObservationType.venueProfileView
      ? _eventId
      : null,
);

void main() {
  for (final type in AnalyticsObservationType.values) {
    test('maps ${type.wireValue} to the fenced collector contract', () async {
      final api = _Api();
      final result = await AnalyticsCollectionRepositoryImpl(api).collect(
        clientId: _clientId,
        observations: [_observation(type: type)],
        expectedUserId: 'user-a',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, [_observationId]);
      expect(api.method, ApiHttpMethod.post);
      expect(api.path, '/api/v1/analytics/observations');
      expect(api.context?.expectedSessionKey, 'user-a');
      expect(api.context?.requireGuestSession, isFalse);
      expect(api.body, {
        'clientId': _clientId,
        'observations': [_observation(type: type).toJson()],
      });
      final json = (api.body! as Map)['observations'] as List;
      expect((json.single as Map)['observedAt'], '2026-09-08T10:00:00.000Z');
    });
  }

  test('guest collection requires a guest transport fence', () async {
    final api = _Api();
    await AnalyticsCollectionRepositoryImpl(api).collect(
      clientId: _clientId,
      observations: [_observation()],
      expectedUserId: null,
    );
    expect(api.context?.requireGuestSession, isTrue);
    expect(api.context?.expectedSessionKey, isNull);
  });

  for (final raw in <Object?>[
    null,
    {},
    {'accepted': true},
    {'acknowledgedIds': 'invalid'},
    {
      'acknowledgedIds': [1],
    },
    {
      'acknowledgedIds': [_clientId],
    },
    {
      'acknowledgedIds': [_observationId, _observationId],
    },
  ]) {
    test('malformed acknowledgement remains unconfirmed: $raw', () async {
      final api = _Api()..response = raw;
      final result = await AnalyticsCollectionRepositoryImpl(api).collect(
        clientId: _clientId,
        observations: [_observation()],
        expectedUserId: null,
      );
      expect(result.error?.code, 'analytics_unconfirmed');
    });
  }

  test('partial acknowledgement is accepted without fabricating IDs', () async {
    final api = _Api()..response = {'acknowledgedIds': <String>[]};
    final result = await AnalyticsCollectionRepositoryImpl(api).collect(
      clientId: _clientId,
      observations: [_observation()],
      expectedUserId: null,
    );
    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
  });

  for (final count in [0, 21]) {
    test('rejects batch length $count before network', () async {
      final api = _Api();
      final result = await AnalyticsCollectionRepositoryImpl(api).collect(
        clientId: _clientId,
        observations: List.generate(count, (_) => _observation()),
        expectedUserId: null,
      );
      expect(result.error?.code, 'analytics_invalid');
      expect(api.path, isNull);
    });
  }

  test(
    'duplicate observation IDs and invalid identity never dispatch',
    () async {
      final api = _Api();
      final repository = AnalyticsCollectionRepositoryImpl(api);
      for (final client in ['bad', _clientId]) {
        final result = await repository.collect(
          clientId: client,
          observations: [_observation(), _observation()],
          expectedUserId: null,
        );
        expect(result.error?.code, 'analytics_invalid');
      }
      expect(api.path, isNull);
    },
  );

  test('preserves network and permanent server error codes', () async {
    for (final code in ['network', '429', '503', '400', 'api_session_fence']) {
      final api = _Api()
        ..error = ApiException(AppError(code: code, message: 'failure'));
      final result = await AnalyticsCollectionRepositoryImpl(api).collect(
        clientId: _clientId,
        observations: [_observation()],
        expectedUserId: null,
      );
      expect(result.error?.code, code);
    }
  });

  test('stored observation rejects mismatched entity fields', () {
    expect(
      () => AnalyticsObservation.fromJson({
        ..._observation().toJson(),
        'venueId': _venueId,
      }),
      throwsFormatException,
    );
    final observation = _observation(
      type: AnalyticsObservationType.venueProfileView,
    );
    expect(
      AnalyticsObservation.fromJson(observation.toJson()).toJson(),
      observation.toJson(),
    );
  });
}

class _Api extends ApiClient {
  Object? response = const {
    'acknowledgedIds': [_observationId],
  };
  Object? error;
  ApiHttpMethod? method;
  String? path;
  Object? body;
  ApiRequestContext? context;

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    this.method = method;
    this.path = path;
    this.body = body;
    context = requestContext;
    if (error != null) throw error!;
    return decoder!(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
