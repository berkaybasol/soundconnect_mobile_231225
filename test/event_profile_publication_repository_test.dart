import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_profile_publication_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/event_profile_publication_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/musician_calendar_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_profile_publication.dart';

const _eventId = '11111111-1111-4111-8111-111111111111';
const _otherEventId = '22222222-2222-4222-8222-222222222222';
const _musicianId = '33333333-3333-4333-8333-333333333333';
const _bandId = '44444444-4444-4444-8444-444444444444';
const _venueId = '55555555-5555-4555-8555-555555555555';
const _basePath = '/api/v1/user/event-profile-publications';

void main() {
  late _PublicationApi api;
  late EventProfilePublicationRepositoryImpl repository;
  String? session;
  var notifications = 0;

  setUp(() {
    api = _PublicationApi();
    session = 'owner-session';
    notifications = 0;
    repository = EventProfilePublicationRepositoryImpl(
      api,
      sessionKeyProvider: () => session,
      onPublicationChanged: () => notifications++,
    );
  });

  for (final type in EventPerformerTargetType.values) {
    test(
      '${type.name} lists only its profile with a transport session fence',
      () async {
        final id = type == EventPerformerTargetType.band
            ? _bandId
            : _musicianId;
        api.value = _page([_item(type: type)]);
        final result = await repository.listMine(
          targetType: type,
          targetId: ' $id ',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.items.single.targetId, id);
        expect(api.calls.single.method, ApiHttpMethod.get);
        expect(api.calls.single.path, _basePath);
        expect(api.calls.single.query, {
          'targetType': type.wireValue,
          'targetId': id,
          'page': 0,
          'size': 20,
        });
        expect(api.calls.single.context?.expectedSessionKey, session);
        expect(api.calls.single.body, isNull);
        expect(notifications, 0);
        expect(() => result.data!.items.clear(), throwsUnsupportedError);
      },
    );

    for (final visible in [true, false]) {
      test(
        '${type.name} ${visible ? 'show' : 'hide'} sends only scoped publication choice',
        () async {
          final id = type == EventPerformerTargetType.band
              ? _bandId
              : _musicianId;
          api.value = _item(type: type, visible: visible, version: 5);
          final result = await repository.setVisible(
            eventId: _eventId,
            targetType: type,
            targetId: id,
            visible: visible,
            version: 4,
          );
          expect(result.isSuccess, isTrue);
          expect(result.data!.visible, visible);
          expect(result.data!.version, 5);
          expect(api.calls.single.method, ApiHttpMethod.put);
          expect(api.calls.single.path, '$_basePath/$_eventId');
          expect(api.calls.single.body, {
            'targetType': type.wireValue,
            'targetId': id,
            'visible': visible,
            'version': 4,
          });
          expect(api.calls.single.context?.expectedSessionKey, session);
          expect(notifications, 1);
        },
      );
    }
  }

  test(
    'personal band-event preference remains under the member target',
    () async {
      api.value = _page([
        {..._item(), 'performerName': 'Şahbaz'},
      ]);
      final result = await repository.listMine(
        targetType: EventPerformerTargetType.musician,
        targetId: _musicianId,
      );
      expect(result.data!.items.single.performerName, 'Şahbaz');
      expect(result.data!.items.single.targetId, _musicianId);
      expect(
        result.data!.items.single.targetType,
        EventPerformerTargetType.musician,
      );
      expect(api.calls, hasLength(1));
    },
  );

  for (final period in EventProfilePublicationPeriod.values) {
    test('${period.name} is server-filtered before pagination', () async {
      api.value = _page([_item()], page: 1, size: 2, totalElements: 5);
      final result = await repository.listMine(
        targetType: EventPerformerTargetType.musician,
        targetId: _musicianId,
        period: period,
        page: 1,
        size: 2,
      );
      expect(result.isSuccess, isTrue);
      expect(
        api.calls.single.query?['period'],
        period == EventProfilePublicationPeriod.all ? isNull : period.wireValue,
      );
      expect(api.calls.single.query?['page'], 1);
      expect(api.calls.single.query?['size'], 2);
      expect(api.calls.single.context?.expectedSessionKey, session);
      expect(result.data!.page, 1);
      expect(result.data!.items, hasLength(1));
      expect(result.data!.totalElements, 5);
      expect(result.data!.totalPages, 3);
      expect(result.data!.hasNext, isTrue);
      expect(api.calls, hasLength(1));
    });
  }

  test('no-op confirmed update preserves the version', () async {
    api.value = _item(visible: false, version: 4);
    final result = await _update(repository);
    expect(result.isSuccess, isTrue);
    expect(result.data!.version, 4);
    expect(api.calls, hasLength(1));
    expect(notifications, 1);
  });

  test(
    'observer failure cannot turn a committed change into failure',
    () async {
      repository = EventProfilePublicationRepositoryImpl(
        api,
        sessionKeyProvider: () => session,
        onPublicationChanged: () => throw StateError('Observer failed'),
      );
      api.value = _item(visible: false, version: 5);
      expect((await _update(repository)).isSuccess, isTrue);
      expect(api.calls, hasLength(1));
    },
  );

  for (final missing in <String?>[null, '', '   ']) {
    test(
      'missing session $missing fails before either endpoint dispatches',
      () async {
        session = missing;
        expect(
          (await _list(repository)).error?.code,
          'event_profile_publication_session_changed',
        );
        expect(
          (await _update(repository)).error?.code,
          'event_profile_publication_session_changed',
        );
        expect(api.calls, isEmpty);
        expect(notifications, 0);
      },
    );
  }

  for (final mutation in [false, true]) {
    for (final resultKind in [
      'success',
      'malformed',
      'apiError',
      'unknownError',
    ]) {
      test(
        '${mutation ? 'update' : 'list'} drops $resultKind after account change',
        () async {
          final pending = Completer<Object?>();
          api.pending = pending.future;
          final future = mutation ? _update(repository) : _list(repository);
          session = 'other-owner';
          if (resultKind == 'apiError') {
            pending.completeError(
              ApiException(
                const AppError(code: '403', message: 'Old user error'),
              ),
            );
          } else if (resultKind == 'unknownError') {
            pending.completeError(StateError('Old user error'));
          } else {
            pending.complete(
              resultKind == 'malformed'
                  ? null
                  : mutation
                  ? _item(visible: false, version: 5)
                  : _page([_item()]),
            );
          }
          final result = await future;
          expect(
            result.error?.code,
            'event_profile_publication_session_changed',
          );
          expect(result.data, isNull);
          expect(notifications, 0);
          expect(api.calls, hasLength(1));
        },
      );
    }
  }

  test(
    'unsupported transport fence fails closed without unfenced fallback',
    () async {
      final unsafeApi = _UnfencedApi();
      repository = EventProfilePublicationRepositoryImpl(
        unsafeApi,
        sessionKeyProvider: () => session,
      );
      expect((await _list(repository)).isSuccess, isFalse);
      expect((await _update(repository)).isSuccess, isFalse);
      expect(unsafeApi.dispatches, 0);
    },
  );

  for (final failure in [
    ApiException(
      const AppError(code: '409', message: 'Başka bir cihazda değişti.'),
    ),
    ApiException(const AppError(code: '403', message: 'Yetkin yok.')),
    TimeoutException('Unknown commit outcome'),
  ]) {
    test(
      'mutation $failure is never automatically retried or broadcast',
      () async {
        api.failure = failure;
        final result = await _update(repository);
        expect(result.isSuccess, isFalse);
        if (failure is ApiException) expect(result.error, same(failure.error));
        expect(api.calls, hasLength(1));
        expect(notifications, 0);
      },
    );
  }

  for (final id in ['', 'event/../../other', 'not-a-uuid']) {
    test('invalid identity $id never reaches the server', () async {
      expect(
        (await repository.listMine(
          targetType: EventPerformerTargetType.musician,
          targetId: id,
        )).isSuccess,
        isFalse,
      );
      expect(
        (await repository.setVisible(
          eventId: id,
          targetType: EventPerformerTargetType.musician,
          targetId: _musicianId,
          visible: true,
          version: 0,
        )).isSuccess,
        isFalse,
      );
      expect(
        (await repository.setVisible(
          eventId: _eventId,
          targetType: EventPerformerTargetType.musician,
          targetId: id,
          visible: true,
          version: 0,
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, isEmpty);
    });
  }

  for (final bounds in [(-1, 20), (101, 20), (0, 0), (0, 51)]) {
    test('invalid page bounds $bounds never dispatch', () async {
      final result = await repository.listMine(
        targetType: EventPerformerTargetType.musician,
        targetId: _musicianId,
        page: bounds.$1,
        size: bounds.$2,
      );
      expect(result.error?.code, 'event_profile_publication_invalid_request');
      expect(api.calls, isEmpty);
    });
  }

  for (final version in [-1, EventProfilePublicationModel.maxSafeVersion]) {
    test('unsafe update version $version never dispatches', () async {
      final result = await repository.setVisible(
        eventId: _eventId,
        targetType: EventPerformerTargetType.musician,
        targetId: _musicianId,
        visible: false,
        version: version,
      );
      expect(result.error?.code, 'event_profile_publication_invalid_request');
      expect(api.calls, isEmpty);
    });
  }

  final inconsistentUpdates = <String, Map<String, dynamic>>{
    'different event': {'eventId': _otherEventId},
    'different target': {'targetId': _bandId},
    'different target type': {'targetType': 'BAND'},
    'different choice': {'visible': true},
    'older version': {'version': 3},
    'unrequested later version': {'version': 6},
  };
  for (final entry in inconsistentUpdates.entries) {
    test(
      'unconfirmed update ${entry.key} is rejected without notification',
      () async {
        api.value = {..._item(visible: false, version: 5), ...entry.value};
        final result = await _update(repository);
        expect(
          result.error?.code,
          'event_profile_publication_invalid_response',
        );
        expect(notifications, 0);
        expect(api.calls, hasLength(1));
      },
    );
  }

  test('empty and out-of-range pages remain valid after list shrink', () async {
    api.value = _page([]);
    final first = await _list(repository);
    expect(first.isSuccess, isTrue);
    expect(first.data!.hasNext, isFalse);
    expect(first.data!.isOutOfRange, isFalse);
    api.value = _page([], page: 2, totalElements: 1);
    final later = await repository.listMine(
      targetType: EventPerformerTargetType.musician,
      targetId: _musicianId,
      page: 2,
    );
    expect(later.isSuccess, isTrue);
    expect(later.data!.isOutOfRange, isTrue);
  });

  test('page metadata and next-page boundary are preserved', () async {
    api.value = _page(
      [_item(), _item(eventId: _otherEventId)],
      size: 2,
      totalElements: 3,
    );
    final result = await repository.listMine(
      targetType: EventPerformerTargetType.musician,
      targetId: _musicianId,
      size: 2,
    );
    expect(result.isSuccess, isTrue);
    expect(result.data!.hasNext, isTrue);
    expect(result.data!.totalPages, 2);
    expect(result.data!.totalElements, 3);
  });

  final invalidPages = <String, Object?>{
    'null': null,
    'legacy list': [_item()],
    'missing content': {
      ..._page([_item()]),
      'content': null,
    },
    'nonobject item': _page([null]),
    'duplicate event': _page([_item(), _item()]),
    'wrong scope': _page([_item(type: EventPerformerTargetType.band)]),
    'wrong profile': _page([
      {..._item(), 'targetId': _bandId},
    ]),
    'wrong page': {
      ..._page([_item()]),
      'page': 1,
    },
    'wrong size': {
      ..._page([_item()]),
      'size': 19,
    },
    'negative total': {
      ..._page([_item()]),
      'totalElements': -1,
    },
    'string integer': {
      ..._page([_item()]),
      'totalElements': '1',
    },
    'fractional integer': {
      ..._page([_item()]),
      'totalElements': 1.0,
    },
    'unsafe total': {
      ..._page([_item()]),
      'totalElements': 9007199254740992,
    },
    'wrong total pages': {
      ..._page([_item()]),
      'totalPages': 2,
    },
    'wrong first': {
      ..._page([_item()]),
      'first': false,
    },
    'wrong last': {
      ..._page([_item()]),
      'last': false,
    },
    'missing flag': {
      ..._page([_item()]),
      'last': null,
    },
    'mismatching aliases': {
      ..._page([_item()]),
      'number': 1,
    },
  };
  for (final entry in invalidPages.entries) {
    test('list rejects ${entry.key} without exposing partial items', () async {
      api.value = entry.value;
      final result = await _list(repository);
      expect(result.error?.code, 'event_profile_publication_invalid_response');
      expect(result.data, isNull);
      expect(notifications, 0);
    });
  }

  test(
    'safe filtering after concurrent deletion preserves page metadata',
    () async {
      api.value = _page([_item()], size: 2, totalElements: 3);
      final result = await repository.listMine(
        targetType: EventPerformerTargetType.musician,
        targetId: _musicianId,
        size: 2,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.items, hasLength(1));
      expect(result.data!.hasNext, isTrue);
      expect(result.data!.totalElements, 3);
      expect(result.data!.totalPages, 2);
      expect(notifications, 0);
    },
  );

  test(
    'successful publication update refreshes live personal and band calendars once',
    () async {
      final personal = MusicianCalendarRepositoryImpl(
        api,
        sessionKeyProvider: () => session,
      );
      final factory = BandCalendarRepositoryFactory(
        api,
        sessionKeyProvider: () => session,
        refreshes: personal.changes,
      );
      final band = factory.acquire(_bandId);
      final counts = [0, 0];
      final subscriptions = [
        personal.changes.listen((_) => counts[0]++),
        band.changes.listen((_) => counts[1]++),
      ];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await factory.dispose();
        await personal.dispose();
      });
      repository = EventProfilePublicationRepositoryImpl(
        api,
        sessionKeyProvider: () => session,
        onPublicationChanged: personal.invalidate,
      );
      api.value = _item(visible: false, version: 5);
      expect((await _update(repository)).isSuccess, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(counts, [1, 1]);
      await Future<void>.delayed(Duration.zero);
      expect(counts, [1, 1]);
      expect(api.calls, hasLength(1));
    },
  );
}

Future<Result<EventProfilePublicationPage>> _list(
  EventProfilePublicationRepositoryImpl repository,
) => repository.listMine(
  targetType: EventPerformerTargetType.musician,
  targetId: _musicianId,
);
Future<Result<EventProfilePublication>> _update(
  EventProfilePublicationRepositoryImpl repository,
) => repository.setVisible(
  eventId: _eventId,
  targetType: EventPerformerTargetType.musician,
  targetId: _musicianId,
  visible: false,
  version: 4,
);

Map<String, dynamic> _item({
  String eventId = _eventId,
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  bool visible = true,
  int version = 4,
}) => {
  'eventId': eventId,
  'targetType': type.wireValue,
  'targetId': type == EventPerformerTargetType.band ? _bandId : _musicianId,
  'visible': visible,
  'version': version,
  'eventTitle': 'Eylül Akşamı',
  'eventDate': '2026-09-06',
  'startTime': '20:00:00',
  'endTime': '22:00:00',
  'posterImage': null,
  'venueId': _venueId,
  'venueName': 'soundconnectankara',
  'performerName': type == EventPerformerTargetType.band
      ? 'Şahbaz'
      : 'bugrasahin',
};

Map<String, dynamic> _page(
  List<Object?> items, {
  int page = 0,
  int size = 20,
  int? totalElements,
}) {
  final total = totalElements ?? items.length;
  final pages = total == 0 ? 0 : (total + size - 1) ~/ size;
  return {
    'content': items,
    'page': page,
    'size': size,
    'totalElements': total,
    'totalPages': pages,
    'first': page == 0,
    'last': pages == 0 || page + 1 >= pages,
  };
}

class _ApiCall {
  _ApiCall(this.method, this.path, this.body, this.query, this.context);
  final ApiHttpMethod method;
  final String path;
  final Object? body;
  final Map<String, dynamic>? query;
  final ApiRequestContext? context;
}

class _PublicationApi extends ApiClient {
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
    calls.add(_ApiCall(method, path, body, query, requestContext));
    if (failure != null) throw failure!;
    return decoder!(pending == null ? value : await pending!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnfencedApi extends ApiClient {
  int dispatches = 0;
  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
  }) async {
    dispatches++;
    return decoder!(_page([_item()]));
  }

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object?)? decoder,
  }) async {
    dispatches++;
    return decoder!(_item(visible: false, version: 5));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
