import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_performer_request_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/event_performer_request_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';

void main() {
  group('server decision eligibility', () {
    test('legacy metadata never claims reconsideration eligibility', () {
      final json = _request(status: 'REJECTED')
        ..remove('decisionAllowed')
        ..remove('canReconsider')
        ..remove('expired')
        ..remove('serverNow')
        ..remove('eventStartsAt');
      final item = EventPerformerRequestModel.fromJson(json);
      expect(item.decisionAllowed, isNull);
      expect(item.canReconsider, isNull);
      expect(item.expired, isNull);
      expect(item.serverNow, isNull);
      expect(item.eventStartsAt, isNull);
    });

    for (final status in ['PENDING', 'REJECTED']) {
      for (final expired in [false, true]) {
        test('$status expiry $expired preserves authoritative flags', () {
          final item = EventPerformerRequestModel.fromJson(
            _request(status: status, expired: expired),
          );
          expect(item.expired, expired);
          expect(item.decisionAllowed, status == 'PENDING' && !expired);
          expect(item.canReconsider, status == 'REJECTED' && !expired);
          expect(item.serverNow, DateTime.utc(2026, 9, 6, 10));
          expect(item.eventStartsAt, DateTime.utc(2026, 9, 8, 17));
        });
      }
    }

    for (final key in ['decisionAllowed', 'canReconsider', 'expired']) {
      for (final value in [null, 'true', 1, <String, dynamic>{}]) {
        test('$key rejects malformed boolean $value', () {
          expect(
            () => EventPerformerRequestModel.fromJson({
              ..._request(),
              key: value,
            }),
            throwsFormatException,
          );
        });
      }
    }

    for (final flags in [
      {'status': 'ACCEPTED', 'decisionAllowed': true},
      {'status': 'PENDING', 'canReconsider': true},
      {'status': 'CANCELLED', 'canReconsider': true},
      {'status': 'PENDING', 'decisionAllowed': true, 'expired': true},
      {'status': 'REJECTED', 'canReconsider': true, 'expired': true},
    ]) {
      test('contradictory action flags fail closed: $flags', () {
        expect(
          () => EventPerformerRequestModel.fromJson({..._request(), ...flags}),
          throwsFormatException,
        );
      });
    }

    for (final key in ['serverNow', 'eventStartsAt']) {
      test('$key accepts an explicit offset and normalizes to UTC', () {
        final item = EventPerformerRequestModel.fromJson({
          ..._request(),
          key: '2026-09-06T13:00:00.123456789+03:00',
        });
        final actual = key == 'serverNow' ? item.serverNow : item.eventStartsAt;
        expect(actual, DateTime.utc(2026, 9, 6, 10, 0, 0, 123, 456));
        expect(actual!.isUtc, isTrue);
      });
      for (final value in [
        null,
        1234,
        '',
        '2026-09-06T13:00:00',
        '2026-09-06',
        '2026-02-30T13:00:00Z',
        '2026-13-01T13:00:00Z',
        '2026-09-06T24:00:00Z',
        '2026-09-06T13:60:00Z',
        '2026-09-06T13:00:60Z',
        '2026-09-06T13:00:00+24:00',
      ]) {
        test('$key rejects invalid or unzoned time $value', () {
          expect(
            () => EventPerformerRequestModel.fromJson({
              ..._request(),
              key: value,
            }),
            throwsFormatException,
          );
        });
      }
    }
  });

  group('reconsideration repository', () {
    late _Api api;
    late EventPerformerRequestRepositoryImpl repository;
    String? session;
    var notifications = 0;

    setUp(() {
      api = _Api()..value = _request(status: 'ACCEPTED');
      session = 'owner-a';
      notifications = 0;
      repository = EventPerformerRequestRepositoryImpl(
        api,
        sessionKeyProvider: () => session,
        onDecision: () => notifications++,
      );
    });

    for (final visible in [false, true]) {
      test(
        'reconsider sends explicit $visible through distinct fenced endpoint',
        () async {
          final result = await repository.reconsider(
            ' request-1 ',
            showOnProfile: visible,
          );
          expect(result.isSuccess, isTrue);
          expect(api.calls.single.method, ApiHttpMethod.post);
          expect(
            api.calls.single.path,
            '/api/v1/event-performer-requests/request-1/reconsider',
          );
          expect(api.calls.single.body, {'showOnProfile': visible});
          expect(api.calls.single.context?.expectedSessionKey, 'owner-a');
          expect(notifications, 1);
        },
      );
    }

    test(
      'response with later independent visibility never triggers an extra write',
      () async {
        api.value = {
          ..._request(status: 'ACCEPTED'),
          'profileCalendarApproved': false,
        };
        expect(
          (await repository.reconsider(
            'request-1',
            showOnProfile: true,
          )).isSuccess,
          isTrue,
        );
        expect(api.calls, hasLength(1));
        expect(notifications, 1);
      },
    );

    test('observer failure does not undo confirmed reconsideration', () async {
      repository = EventPerformerRequestRepositoryImpl(
        api,
        sessionKeyProvider: () => session,
        onDecision: () => throw StateError('Observer'),
      );
      expect(
        (await repository.reconsider(
          'request-1',
          showOnProfile: false,
        )).isSuccess,
        isTrue,
      );
      expect(api.calls, hasLength(1));
    });

    for (final value in <String?>[null, '', '  ']) {
      test('missing session $value rejects before dispatch', () async {
        session = value;
        final result = await repository.reconsider(
          'request-1',
          showOnProfile: false,
        );
        expect(result.error?.code, 'event_performer_session_changed');
        expect(api.calls, isEmpty);
        expect(notifications, 0);
      });
    }

    test('missing request identity rejects before dispatch', () async {
      expect(
        (await repository.reconsider(' ', showOnProfile: false)).isSuccess,
        isFalse,
      );
      expect(api.calls, isEmpty);
    });

    for (final malformed in <Object?>[
      null,
      [],
      {..._request(status: 'ACCEPTED'), 'id': 'another-request'},
      _request(status: 'REJECTED'),
      {..._request(status: 'ACCEPTED'), 'bandId': 'forbidden-band'},
      {..._request(status: 'ACCEPTED'), 'profileCalendarApproved': null},
    ]) {
      test(
        'unconfirmed response never broadcasts success: $malformed',
        () async {
          api.value = malformed;
          final result = await repository.reconsider(
            'request-1',
            showOnProfile: false,
          );
          expect(result.error?.code, 'event_performer_decision_unconfirmed');
          expect(api.calls, hasLength(1));
          expect(notifications, 0);
        },
      );
    }

    for (final error in [
      ApiException(const AppError(code: '403', message: 'Yetkin yok.')),
      ApiException(const AppError(code: '409', message: 'Davet değişti.')),
      TimeoutException('Unknown server outcome'),
    ]) {
      test('failed reconsideration is never retried: $error', () async {
        api.failure = error;
        final result = await repository.reconsider(
          'request-1',
          showOnProfile: false,
        );
        expect(result.isSuccess, isFalse);
        if (error is ApiException) expect(result.error, same(error.error));
        expect(api.calls, hasLength(1));
        expect(notifications, 0);
      });
    }

    for (final operation in ['reconsider', 'rejected-list']) {
      for (final outcome in [
        'success',
        'malformed',
        'api-error',
        'unknown-error',
      ]) {
        test('$operation drops stale-session $outcome', () async {
          final pending = Completer<Object?>();
          api.pending = pending.future;
          final resultFuture = operation == 'reconsider'
              ? repository.reconsider('request-1', showOnProfile: false)
              : repository.listMine(
                  status: EventPerformerRequestStatus.rejected,
                );
          session = 'owner-b';
          if (outcome == 'api-error') {
            pending.completeError(
              ApiException(const AppError(code: '409', message: 'Old owner')),
            );
          } else if (outcome == 'unknown-error') {
            pending.completeError(StateError('Old owner'));
          } else {
            pending.complete(
              outcome == 'malformed'
                  ? null
                  : operation == 'reconsider'
                  ? _request(status: 'ACCEPTED')
                  : _page([_request(status: 'REJECTED')]),
            );
          }
          final result = await resultFuture;
          expect(result.error?.code, 'event_performer_session_changed');
          expect(result.isSuccess, isFalse);
          expect(notifications, 0);
          expect(api.calls, hasLength(1));
        });
      }
    }

    test('rejected pagination retains expired rows and metadata', () async {
      api.value = _page(
        [_request(status: 'REJECTED', expired: true)],
        page: 1,
        size: 2,
        total: 5,
      );
      final result = await repository.listMine(
        status: EventPerformerRequestStatus.rejected,
        targetType: EventPerformerTargetType.musician,
        targetId: ' musician-1 ',
        page: 1,
        size: 2,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.items.single.expired, isTrue);
      expect(result.data!.items.single.canReconsider, isFalse);
      expect(result.data!.page, 1);
      expect(result.data!.hasNext, isTrue);
      expect(result.data!.totalElements, 5);
      expect(result.data!.totalPages, 3);
      expect(api.calls.single.context?.expectedSessionKey, 'owner-a');
      expect(api.calls.single.query, {
        'status': 'REJECTED',
        'targetType': 'MUSICIAN',
        'targetId': 'musician-1',
        'page': 1,
        'size': 2,
      });
      expect(() => result.data!.items.clear(), throwsUnsupportedError);
    });

    test(
      'expired pending requests remain visible as read-only decisions',
      () async {
        api.value = _page([_request(expired: true)]);
        final result = await repository.listMine();
        expect(result.isSuccess, isTrue);
        expect(result.data!.items.single.expired, isTrue);
        expect(result.data!.items.single.decisionAllowed, isFalse);
      },
    );

    test(
      'different target is rejected before returning private history',
      () async {
        api.value = _page([_request(status: 'REJECTED')]);
        final result = await repository.listMine(
          status: EventPerformerRequestStatus.rejected,
          targetType: EventPerformerTargetType.musician,
          targetId: 'another-musician',
        );
        expect(
          result.error?.code,
          'event_performer_requests_malformed_response',
        );
        expect(result.data, isNull);
      },
    );

    test('request page bounds follow the server maximum', () async {
      final result = await repository.listMine(page: 101);
      expect(result.error?.code, 'event_performer_requests_invalid_page');
      expect(api.calls, isEmpty);
    });
  });
}

Map<String, dynamic> _request({
  String status = 'PENDING',
  bool expired = false,
}) => {
  'id': 'request-1',
  'eventId': 'event-1',
  'eventTitle': 'Eylül Gecesi',
  'eventDate': '2026-09-08',
  'startTime': '20:00:00',
  'endTime': '22:00:00',
  'venueId': 'venue-1',
  'venueName': 'SoundConnect Ankara',
  'performerType': 'MUSICIAN',
  'musicianProfileId': 'musician-1',
  'performerName': 'bugrasahin',
  'status': status,
  'requestPurpose': 'PERFORMER_CONSENT',
  'profileCalendarApproved': false,
  'decisionAllowed': status == 'PENDING' && !expired,
  'canReconsider': status == 'REJECTED' && !expired,
  'expired': expired,
  'serverNow': '2026-09-06T10:00:00Z',
  'eventStartsAt': '2026-09-08T17:00:00Z',
};

Map<String, dynamic> _page(
  List<Object?> items, {
  int page = 0,
  int size = 20,
  int? total,
}) {
  final count = total ?? items.length;
  final pages = count == 0 ? 0 : (count + size - 1) ~/ size;
  return {
    'content': items,
    'page': page,
    'size': size,
    'totalElements': count,
    'totalPages': pages,
    'first': page == 0,
    'last': pages == 0 || page + 1 >= pages,
  };
}

class _Call {
  _Call(this.method, this.path, this.body, this.query, this.context);
  final ApiHttpMethod method;
  final String path;
  final Object? body;
  final Map<String, dynamic>? query;
  final ApiRequestContext? context;
}

class _Api extends ApiClient {
  Object? value;
  Object? failure;
  Future<Object?>? pending;
  final calls = <_Call>[];

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls.add(_Call(method, path, body, query, requestContext));
    if (failure != null) throw failure!;
    return decoder!(pending == null ? value : await pending!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
