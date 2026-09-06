import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_performer_request_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/event_performer_request_model.dart';

void main() {
  Map<String, dynamic> wire() => {
    'id': 'request-1',
    'eventId': 'event-1',
    'performerType': 'BAND',
    'bandId': 'band-1',
    'status': 'PENDING',
    'requestPurpose': 'PERFORMER_CONSENT',
  };

  test('legacy response does not claim independent publication support', () {
    expect(
      EventPerformerRequestModel.fromJson(wire()).profileCalendarApproved,
      isNull,
    );
  });
  for (final value in [false, true]) {
    test(
      'publication approval is decoded as an independent boolean: $value',
      () {
        final model = EventPerformerRequestModel.fromJson({
          ...wire(),
          'profileCalendarApproved': value,
        });
        expect(model.profileCalendarApproved, value);
      },
    );
  }
  for (final value in [null, 'true', 'false', 0, 1, <String, dynamic>{}]) {
    test('malformed publication flag is not treated as consent: $value', () {
      expect(
        () => EventPerformerRequestModel.fromJson({
          ...wire(),
          'profileCalendarApproved': value,
        }),
        throwsFormatException,
      );
    });
  }

  for (final fenced in [false, true]) {
    test(
      'accept defaults to explicit false on wire, session fenced: $fenced',
      () async {
        final api = _DecisionApi();
        final repository = EventPerformerRequestRepositoryImpl(
          api,
          sessionKeyProvider: fenced ? () => 'owner-1' : null,
        );
        expect((await repository.accept(' request-1 ')).isSuccess, isTrue);
        expect(api.path, '/api/v1/event-performer-requests/request-1/accept');
        expect(api.body, {'showOnProfile': false});
        expect(api.context?.expectedSessionKey, fenced ? 'owner-1' : null);
        expect(api.calls, 1);
      },
    );
    test(
      'checked option sends explicit true, session fenced: $fenced',
      () async {
        final api = _DecisionApi();
        final repository = EventPerformerRequestRepositoryImpl(
          api,
          sessionKeyProvider: fenced ? () => 'owner-1' : null,
        );
        expect(
          (await repository.accept('request-1', showOnProfile: true)).isSuccess,
          isTrue,
        );
        expect(api.body, {'showOnProfile': true});
        expect(api.calls, 1);
      },
    );
  }
  test(
    'reject keeps its endpoint and never sends a publication grant',
    () async {
      final api = _DecisionApi();
      expect(
        (await EventPerformerRequestRepositoryImpl(
          api,
        ).reject('request-1')).isSuccess,
        isTrue,
      );
      expect(api.path, '/api/v1/event-performer-requests/request-1/reject');
      expect(api.body, isNull);
    },
  );
}

class _DecisionApi extends Fake implements ApiClient {
  String? path;
  Object? body;
  ApiRequestContext? context;
  int calls = 0;
  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    calls++;
    this.path = path;
    this.body = body;
    return decoder!(null);
  }

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) {
    expect(method, ApiHttpMethod.post);
    context = requestContext;
    return post(path, body: body, decoder: decoder);
  }
}
