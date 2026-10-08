import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/venue_event_repository_impl.dart';

const _venueId = '11111111-1111-4111-8111-111111111111';
const _otherVenueId = '22222222-2222-4222-8222-222222222222';
const _path = '/api/v1/venue-owner/events/venue/$_venueId';
final _asOf = DateTime.parse('2026-09-21T18:30:00.123456Z');

void main() {
  late _ManagementApi api;
  late VenueEventRepositoryImpl repository;
  String? session;

  setUp(() {
    api = _ManagementApi();
    session = 'owner';
    repository = VenueEventRepositoryImpl(
      api,
      sessionKeyProvider: () => session,
    );
  });

  test(
    'management loads upcoming rows and a count without history rows',
    () async {
      api.value = _snapshot([_event()], count: 15000);
      final result = await repository.loadManagement(' $_venueId ');
      expect(result.isSuccess, isTrue);
      expect(result.data!.pastCount, 15000);
      expect(result.data!.upcomingEvents.single.title, 'Yeni etkinlik');
      expect(result.data!.historyAsOf, _asOf);
      expect(result.data!.historyAsOf.isUtc, isTrue);
      expect(() => result.data!.upcomingEvents.clear(), throwsUnsupportedError);
      expect(api.calls, hasLength(1));
      expect(api.calls.single.path, '$_path/management');
      expect(api.calls.single.method, ApiHttpMethod.get);
      expect(api.calls.single.query, isNull);
      expect(api.calls.single.context?.expectedSessionKey, session);
    },
  );

  test('empty management and history snapshots remain valid', () async {
    api.value = _snapshot([]);
    final management = await repository.loadManagement(_venueId);
    expect(management.isSuccess, isTrue);
    expect(management.data!.upcomingEvents, isEmpty);
    expect(management.data!.pastCount, 0);
    api.value = _page([]);
    final history = await repository.loadHistory(_venueId, asOf: _asOf);
    expect(history.isSuccess, isTrue);
    expect(history.data!.items, isEmpty);
    expect(history.data!.hasNext, isFalse);
    expect(history.data!.nextCursor, isNull);
  });

  test(
    'history sends 20-row bound and keeps the same instant across cursors',
    () async {
      api.value = _page(_events(20), nextCursor: 'opaque_page_2');
      final first = await repository.loadHistory(_venueId, asOf: _asOf);
      expect(first.isSuccess, isTrue);
      expect(first.data!.items, hasLength(20));
      expect(first.data!.hasNext, isTrue);
      expect(first.data!.nextCursor, 'opaque_page_2');
      expect(() => first.data!.items.clear(), throwsUnsupportedError);
      api.value = _page([_event(index: 21)]);
      final next = await repository.loadHistory(
        _venueId,
        asOf: _asOf.toLocal(),
        cursor: first.data!.nextCursor,
      );
      expect(next.isSuccess, isTrue);
      expect(next.data!.items.single.id, _event(index: 21)['id']);
      expect(next.data!.hasNext, isFalse);
      expect(api.calls, hasLength(2));
      for (final call in api.calls) {
        expect(call.method, ApiHttpMethod.get);
        expect(call.path, '$_path/history');
        expect(call.context?.expectedSessionKey, session);
      }
      expect(api.calls.first.query, {
        'asOf': _asOf.toIso8601String(),
        'size': 20,
      });
      expect(api.calls.last.query, {
        'asOf': _asOf.toIso8601String(),
        'cursor': 'opaque_page_2',
        'size': 20,
      });
    },
  );

  final malformedSnapshots = <String, Object?>{
    'null envelope': null,
    'legacy list envelope': [_event()],
    'missing upcoming list': {
      'pastCount': 0,
      'historyAsOf': _asOf.toIso8601String(),
    },
    'null upcoming list': {..._snapshot([]), 'upcomingEvents': null},
    'string count': {..._snapshot([]), 'pastCount': '5'},
    'fractional count': {..._snapshot([]), 'pastCount': 1.0},
    'negative count': {..._snapshot([]), 'pastCount': -1},
    'unsafe count': {..._snapshot([]), 'pastCount': 9007199254740992},
    'missing history boundary': {..._snapshot([]), 'historyAsOf': null},
    'unqualified boundary': {
      ..._snapshot([]),
      'historyAsOf': '2026-09-21T18:30:00',
    },
    'boundary with overflowed date': {
      ..._snapshot([]),
      'historyAsOf': '2026-02-31T18:30:00Z',
    },
    'boundary with overflowed time': {
      ..._snapshot([]),
      'historyAsOf': '2026-09-21T24:00:00Z',
    },
  };
  for (final entry in malformedSnapshots.entries) {
    test('management rejects ${entry.key} without legacy fallback', () async {
      api.value = entry.value;
      final result = await repository.loadManagement(_venueId);
      expect(result.error?.code, 'venue_event_management_invalid_response');
      expect(result.data, isNull);
      expect(api.calls, hasLength(1));
      expect(api.calls.single.path, '$_path/management');
    });
  }

  final malformedPages = <String, Object?>{
    'legacy list': [_event()],
    'missing items': {'hasNext': false, 'nextCursor': null},
    'oversized history': _page(_events(21)),
    'missing hasNext': {..._page([]), 'hasNext': null},
    'nonboolean hasNext': {..._page([]), 'hasNext': 'false'},
    'cursor on final page': {..._page([]), 'nextCursor': 'unused_cursor'},
    'missing cursor on nonfinal page': {'items': _events(20), 'hasNext': true},
    'blank cursor': {'items': _events(20), 'hasNext': true, 'nextCursor': ''},
    'nontext cursor': {'items': _events(20), 'hasNext': true, 'nextCursor': 3},
    'oversized cursor': _page(_events(20), nextCursor: 'a' * 513),
    'invalid cursor characters': _page(_events(20), nextCursor: 'unsafe?/&'),
    'short nonfinal page': _page([_event()], nextCursor: 'next'),
    'nonfinal empty page': _page([], nextCursor: 'next'),
  };
  for (final entry in malformedPages.entries) {
    test(
      'history rejects ${entry.key} without exposing partial items',
      () async {
        api.value = entry.value;
        final result = await repository.loadHistory(_venueId, asOf: _asOf);
        expect(result.error?.code, 'venue_event_management_invalid_response');
        expect(result.data, isNull);
        expect(api.calls, hasLength(1));
        expect(api.calls.single.path, '$_path/history');
      },
    );
  }

  test(
    'repeated next cursor is rejected to prevent a load-more loop',
    () async {
      api.value = _page(_events(20), nextCursor: 'same_cursor');
      final result = await repository.loadHistory(
        _venueId,
        asOf: _asOf,
        cursor: 'same_cursor',
      );
      expect(result.error?.code, 'venue_event_management_invalid_response');
      expect(result.data, isNull);
    },
  );

  final malformedItems = <String, List<Object?>>{
    'nonobject item': [null],
    'duplicate event': [_event(), _event()],
    'missing event ID': [
      {..._event(), 'id': null},
    ],
    'invalid event ID': [
      {..._event(), 'id': 'event-one'},
    ],
    'different venue': [
      {..._event(), 'venueId': _otherVenueId},
    ],
    'musician-origin event': [
      {..._event(), 'eventOrigin': 'MUSICIAN'},
    ],
    'missing event origin': [
      {..._event(), 'eventOrigin': null},
    ],
    'unknown venue approval status': [
      {..._event(), 'venueApprovalStatus': 'UNKNOWN'},
    ],
    'invalid venue visibility flag': [
      {..._event(), 'venueCalendarApproved': 'false'},
    ],
    'empty title': [
      {..._event(), 'title': ''},
    ],
    'invalid title type': [
      {..._event(), 'title': 3},
    ],
    'missing performer name': [
      {..._event(), 'performerName': null},
    ],
    'missing event date': [
      {..._event(), 'eventDate': null},
    ],
    'overflowed event date': [
      {..._event(), 'eventDate': '2026-02-31'},
    ],
    'date including time': [
      {..._event(), 'eventDate': '2026-09-20T00:00:00Z'},
    ],
    'invalid start time': [
      {..._event(), 'startTime': '24:00'},
    ],
    'invalid end time': [
      {..._event(), 'endTime': '23:60:00'},
    ],
    'invalid optional text': [
      {..._event(), 'description': 5},
    ],
    'unknown performer type': [
      {..._event(), 'performerType': 'OTHER'},
    ],
    'missing musician identity': [
      {..._event(), 'performerType': 'MUSICIAN'},
    ],
    'manual performer with linked identity': [
      {..._event(), 'musicianProfileId': _otherVenueId},
    ],
  };
  for (final entry in malformedItems.entries) {
    test('both endpoints reject ${entry.key} atomically', () async {
      api.value = _snapshot(entry.value);
      final snapshot = await repository.loadManagement(_venueId);
      api.value = _page(entry.value);
      final history = await repository.loadHistory(_venueId, asOf: _asOf);
      for (final result in [snapshot, history]) {
        expect(result.error?.code, 'venue_event_management_invalid_response');
        expect(result.data, isNull);
      }
      expect(api.calls, hasLength(2));
    });
  }

  test('events without a selected performer remain valid', () async {
    api.value = _snapshot([
      {..._event(), 'performerType': null},
    ]);
    final result = await repository.loadManagement(_venueId);
    expect(result.isSuccess, isTrue);
    expect(result.data!.upcomingEvents.single.performerType, 'MANUAL');
  });

  for (final status in ['NOT_REQUIRED', 'PENDING', 'APPROVED', 'REJECTED']) {
    test(
      'owner lists preserve $status events hidden from the public calendar',
      () async {
        final event = {
          ..._event(),
          'venueApprovalStatus': status,
          'venueCalendarApproved': false,
        };
        api.value = _snapshot([event]);
        final snapshot = await repository.loadManagement(_venueId);
        api.value = _page([event]);
        final history = await repository.loadHistory(_venueId, asOf: _asOf);
        expect(snapshot.isSuccess, isTrue);
        expect(history.isSuccess, isTrue);
        for (final item in [
          snapshot.data!.upcomingEvents.single,
          history.data!.items.single,
        ]) {
          expect(item.venueApprovalStatus, status);
          expect(item.venueCalendarApproved, isFalse);
        }
      },
    );
  }

  test(
    'legacy null start times remain manageable in both owner lists',
    () async {
      final event = {..._event(), 'startTime': null, 'endTime': null};
      api.value = _snapshot([event]);
      final snapshot = await repository.loadManagement(_venueId);
      api.value = _page([event]);
      final history = await repository.loadHistory(_venueId, asOf: _asOf);
      expect(snapshot.isSuccess, isTrue);
      expect(history.isSuccess, isTrue);
      for (final item in [
        snapshot.data!.upcomingEvents.single,
        history.data!.items.single,
      ]) {
        expect(item.startTime, isEmpty);
        expect(item.endTime, isNull);
        expect(item.title, 'Yeni etkinlik');
        expect(item.eventDate, DateTime(2026, 9, 20));
      }
    },
  );

  for (final id in ['', 'not-a-uuid', 'event/../../other']) {
    test('invalid venue $id never dispatches either endpoint', () async {
      expect(
        (await repository.loadManagement(id)).error?.code,
        'venue_event_management_invalid_request',
      );
      expect(
        (await repository.loadHistory(id, asOf: _asOf)).error?.code,
        'venue_event_management_invalid_request',
      );
      expect(api.calls, isEmpty);
    });
  }
  for (final cursor in ['', '   ', 'invalid?cursor', 'a' * 513]) {
    test(
      'invalid history cursor is rejected before dispatch: ${cursor.length}',
      () async {
        final result = await repository.loadHistory(
          _venueId,
          asOf: _asOf,
          cursor: cursor,
        );
        expect(result.error?.code, 'venue_event_management_invalid_request');
        expect(api.calls, isEmpty);
      },
    );
  }

  for (final missingSession in <String?>[null, '', '   ']) {
    test('missing session $missingSession never dispatches', () async {
      session = missingSession;
      expect(
        (await repository.loadManagement(_venueId)).error?.code,
        'venue_event_session_changed',
      );
      expect(
        (await repository.loadHistory(_venueId, asOf: _asOf)).error?.code,
        'venue_event_session_changed',
      );
      expect(api.calls, isEmpty);
    });
  }

  for (final history in [false, true]) {
    for (final kind in [
      'success',
      'malformed',
      'apiFailure',
      'unknownFailure',
    ]) {
      test(
        '${history ? 'history' : 'management'} drops stale $kind after account changes',
        () async {
          final pending = Completer<Object?>();
          api.pending = pending.future;
          final response = history
              ? repository.loadHistory(_venueId, asOf: _asOf)
              : repository.loadManagement(_venueId);
          session = 'different-owner';
          if (kind == 'apiFailure') {
            pending.completeError(
              ApiException(
                const AppError(code: '403', message: 'Old account error'),
              ),
            );
          } else if (kind == 'unknownFailure') {
            pending.completeError(StateError('Old account error'));
          } else {
            pending.complete(
              kind == 'malformed'
                  ? null
                  : history
                  ? _page([_event()])
                  : _snapshot([_event()]),
            );
          }
          final result = await response;
          expect(result.error?.code, 'venue_event_session_changed');
          expect(result.data, isNull);
          expect(api.calls, hasLength(1));
        },
      );
    }
  }

  test(
    'unsupported session fence fails closed without unfenced fallback',
    () async {
      final unsafeApi = _UnfencedApi();
      repository = VenueEventRepositoryImpl(
        unsafeApi,
        sessionKeyProvider: () => session,
      );
      expect((await repository.loadManagement(_venueId)).isSuccess, isFalse);
      expect(
        (await repository.loadHistory(_venueId, asOf: _asOf)).isSuccess,
        isFalse,
      );
      expect(unsafeApi.calls, 0);
    },
  );

  for (final failure in [
    ApiException(const AppError(code: '404', message: 'Not available')),
    ApiException(const AppError(code: '403', message: 'Forbidden')),
    TimeoutException('Network unavailable'),
  ]) {
    test(
      'endpoint failure $failure never retries the full historical list',
      () async {
        api.failure = failure;
        final management = await repository.loadManagement(_venueId);
        final history = await repository.loadHistory(_venueId, asOf: _asOf);
        expect(management.isSuccess, isFalse);
        expect(history.isSuccess, isFalse);
        if (failure is ApiException) {
          expect(management.error, same(failure.error));
          expect(history.error, same(failure.error));
        }
        expect(api.calls.map((c) => c.path), [
          '$_path/management',
          '$_path/history',
        ]);
      },
    );
  }
}

Map<String, dynamic> _event({int index = 1}) => {
  'id': 'aaaaaaaa-aaaa-4aaa-8aaa-${index.toString().padLeft(12, '0')}',
  'title': 'Yeni etkinlik',
  'performerName': 'Deneme Sanatçısı',
  'performerType': 'MANUAL',
  'musicianProfileId': null,
  'bandId': null,
  'venueId': _venueId,
  'eventDate': '2026-09-20',
  'startTime': '20:00:00',
  'endTime': '22:00:00',
  'eventOrigin': 'VENUE',
  'venueApprovalStatus': 'APPROVED',
  'venueCalendarApproved': true,
};

List<Object?> _events(int count) =>
    List.generate(count, (i) => _event(index: i + 1));
Map<String, dynamic> _snapshot(List<Object?> events, {int count = 0}) => {
  'upcomingEvents': events,
  'pastCount': count,
  'historyAsOf': _asOf.toIso8601String(),
};
Map<String, dynamic> _page(List<Object?> items, {String? nextCursor}) => {
  'items': items,
  'nextCursor': nextCursor,
  'hasNext': nextCursor != null,
};

class _ApiCall {
  _ApiCall(this.method, this.path, this.query, this.context);
  final ApiHttpMethod method;
  final String path;
  final Map<String, dynamic>? query;
  final ApiRequestContext? context;
}

class _ManagementApi extends ApiClient {
  Object? value;
  Object? failure;
  Future<Object?>? pending;
  final calls = <_ApiCall>[];

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls.add(_ApiCall(method, path, query, requestContext));
    if (failure != null) throw failure!;
    return decoder!(pending == null ? value : await pending!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnfencedApi extends ApiClient {
  int calls = 0;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
  }) async {
    calls++;
    return decoder!(_snapshot([]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
