import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/musician_calendar_repository_impl.dart';

void main() {
  late _CalendarApi api;
  late MusicianCalendarRepositoryImpl repository;
  String? session = 'owner';
  final start = DateTime(2026, 9, 5);
  final end = DateTime(2026, 9, 11);

  setUp(() {
    api = _CalendarApi();
    session = 'owner';
    repository = MusicianCalendarRepositoryImpl(
      api,
      sessionKeyProvider: () => session,
    );
  });
  tearDown(() => repository.dispose());

  test(
    'silent navigation settings read preserves session fence without broadcasting',
    () async {
      var notifications = 0;
      final subscription = repository.changes.listen((_) => notifications++);
      api.value = {'visible': true, 'version': 4};
      final result = await repository.readSettingsWithoutNotification();
      await Future<void>.delayed(Duration.zero);
      expect(result.data?.visible, isTrue);
      expect(result.data?.version, 4);
      expect(api.context?.expectedSessionKey, 'owner');
      expect(api.method, ApiHttpMethod.get);
      expect(notifications, 0);
      await repository.getSettings();
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      api.value = {'visible': false, 'version': 5};
      await repository.updateSettings(visible: false, version: 4);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 2);
      await subscription.cancel();
    },
  );

  test('silent reader does not notify shared confirmation callback', () async {
    var confirmations = 0;
    final scoped = MusicianCalendarRepositoryImpl(
      api,
      sessionKeyProvider: () => session,
      targetBandId: 'band-1',
      onSettingsConfirmed: () => confirmations++,
    );
    addTearDown(scoped.dispose);
    api.value = {'visible': false, 'version': 0};
    expect((await scoped.readSettingsWithoutNotification()).isSuccess, isTrue);
    expect(api.path, '/api/v1/user/bands/band-1/calendar-settings');
    expect(confirmations, 0);
    await scoped.getSettings();
    expect(confirmations, 1);
    api.value = {'visible': true, 'version': 1};
    await scoped.updateSettings(visible: true, version: 0);
    expect(confirmations, 2);
  });

  test('silent reader discards switched-session response', () async {
    final pending = Completer<Object?>();
    api.pending = pending.future;
    final result = repository.readSettingsWithoutNotification();
    session = 'other';
    pending.complete({'visible': true, 'version': 0});
    expect((await result).error?.code, 'musician_calendar_session_changed');
  });

  test(
    'silent reader rejects malformed settings instead of allowing entry',
    () async {
      api.value = {'visible': 'true', 'version': 0};
      final result = await repository.readSettingsWithoutNotification();
      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'musician_calendar_invalid_response');
      expect(result.data, isNull);
    },
  );

  test(
    'calendar sends bounded dates and parses approved musician and band identities',
    () async {
      api.value = _page(
        events: [
          _event(),
          _event(id: 'event-2', band: true),
        ],
      );
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: start,
        endDate: end,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.events.first.musicianProfileId, 'artist');
      expect(result.data!.events.last.bandId, 'band');
      expect(api.path, '/api/v1/public/musician-profiles/artist/calendar');
      expect(api.query, {
        'startDate': '2026-09-05',
        'endDate': '2026-09-11',
        'page': 0,
        'size': 20,
      });
    },
  );

  test('hidden response returns no events and no further page', () async {
    api.value = _page(visible: false);
    final result = await repository.getCalendar(
      profileId: 'artist',
      startDate: start,
      endDate: end,
    );
    expect(result.isSuccess, isTrue);
    expect(result.data!.visible, isFalse);
    expect(result.data!.events, isEmpty);
  });

  test(
    'musician-origin events are rejected even when they target this profile',
    () async {
      api.value = _page(
        events: [
          {
            ..._event(),
            'eventOrigin': 'MUSICIAN',
            'venueId': null,
            'venueName': null,
          },
        ],
      );
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: start,
        endDate: end,
      );
      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'musician_calendar_invalid_response');
      expect(result.data, isNull);
    },
  );

  test(
    'pending reciprocal venue snapshots cannot enter the retained calendar',
    () async {
      api.value = _page(
        events: [
          {
            ..._event(),
            'eventOrigin': 'MUSICIAN',
            'venueId': null,
            'venueName': 'SoundConnect Ankara',
            'venueApprovalStatus': 'PENDING',
          },
        ],
      );
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: start,
        endDate: end,
      );
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
    },
  );

  test(
    'explicit venue origin preserves the legacy calendar contract',
    () async {
      api.value = _page(
        events: [
          {..._event(), 'eventOrigin': 'VENUE'},
        ],
      );
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: start,
        endDate: end,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.events.single.venueId, 'venue');
    },
  );

  for (final entry in <String, Map<String, dynamic>>{
    'hidden leaks events': _page(visible: false, events: [_event()]),
    'hidden claims next page': _page(visible: false)..['hasNext'] = true,
    'wrong profile': _page()..['profileId'] = 'other',
    'wrong date range': _page()..['startDate'] = '2026-09-04',
    'wrong page': _page()..['page'] = 1,
    'invalid visibility': _page()..['visible'] = 'true',
    'numeric band identity': _page(
      events: [_event(band: true)..['bandId'] = 42],
    ),
    'pending/manual identity': _page(
      events: [_event()..['musicianProfileId'] = null],
    ),
    'wrong musician': _page(
      events: [_event()..['musicianProfileId'] = 'other'],
    ),
    'ambiguous performer': _page(events: [_event()..['bandId'] = 'band']),
    'out of range date': _page(
      events: [_event()..['eventDate'] = '2026-10-01'],
    ),
    'normalized invalid date': _page(
      events: [_event()..['eventDate'] = '2026-09-35'],
    ),
    'invalid time': _page(events: [_event()..['startTime'] = '28:13']),
    'duplicate events': _page(events: [_event(), _event()]),
    'missing venue': _page(events: [_event()..['venueId'] = null]),
    'missing venue name': _page(events: [_event()..['venueName'] = null]),
    'musician origin with approved venue': _page(
      events: [_event()..['eventOrigin'] = 'MUSICIAN'],
    ),
    'unknown origin': _page(events: [_event()..['eventOrigin'] = 'FUTURE']),
    'numeric origin': _page(events: [_event()..['eventOrigin'] = 42]),
    'band pretending to be an own-origin event': _page(
      events: [
        {..._event(band: true), 'eventOrigin': 'MUSICIAN', 'venueId': null},
      ],
    ),
  }.entries) {
    test('rejects ${entry.key}', () async {
      api.value = entry.value;
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: start,
        endDate: end,
      );
      expect(result.error?.code, 'musician_calendar_invalid_response');
      expect(result.data, isNull);
    });
  }

  test('invalid range and pagination do not reach transport', () async {
    for (final args in [
      (start, start.subtract(const Duration(days: 1)), 0, 20),
      (start, start.add(const Duration(days: 31)), 0, 20),
      (start, end, 101, 20),
      (start, end, 0, 51),
    ]) {
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: args.$1,
        endDate: args.$2,
        page: args.$3,
        size: args.$4,
      );
      expect(result.isSuccess, isFalse);
    }
    expect(api.calls, 0);
  });

  test(
    'concurrent deletions can shrink a valid slice with a following page',
    () async {
      api.value = _page()..['hasNext'] = true;
      final result = await repository.getCalendar(
        profileId: 'artist',
        startDate: start,
        endDate: end,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.events, isEmpty);
      expect(result.data!.hasNext, isTrue);
    },
  );

  test(
    'authoritative read after lost hide response invalidates mounted calendars',
    () async {
      api.value = {'visible': false, 'version': 1};
      final changed = repository.changes.first;
      final result = await repository.getSettings();
      await changed;
      expect(result.data!.visible, isFalse);
    },
  );

  test(
    'owner settings uses a transport session fence and publishes a confirmed change',
    () async {
      api.value = {'visible': false, 'version': 1};
      final changed = repository.changes.first;
      final result = await repository.updateSettings(
        visible: false,
        version: 0,
      );
      await changed;
      expect(result.data!.visible, isFalse);
      expect(api.context?.expectedSessionKey, 'owner');
      expect(api.method, ApiHttpMethod.put);
      expect(api.body, {'visible': false, 'version': 0});
    },
  );

  test('guest cannot dispatch settings mutation', () async {
    session = null;
    final result = await repository.updateSettings(visible: false, version: 0);
    expect(result.error?.code, 'musician_calendar_session_changed');
    expect(api.calls, 0);
  });

  test('settings response after account switch is discarded', () async {
    final pending = Completer<Object?>();
    api.pending = pending.future;
    final result = repository.getSettings();
    session = 'other';
    pending.complete({'visible': true, 'version': 0});
    expect((await result).error?.code, 'musician_calendar_session_changed');
  });

  test('unconfirmed settings response does not notify observers', () async {
    var notifications = 0;
    final subscription = repository.changes.listen((_) => notifications++);
    api.value = {'visible': true, 'version': 0};
    final result = await repository.updateSettings(visible: false, version: 0);
    await Future<void>.delayed(Duration.zero);
    expect(result.error?.code, 'musician_calendar_invalid_response');
    expect(notifications, 0);
    await subscription.cancel();
  });
}

Map<String, dynamic> _page({
  bool visible = true,
  List<Object?> events = const [],
}) => {
  'profileId': 'artist',
  'startDate': '2026-09-05',
  'endDate': '2026-09-11',
  'visible': visible,
  'events': events,
  'page': 0,
  'size': 20,
  'hasNext': false,
};

Map<String, dynamic> _event({String id = 'event-1', bool band = false}) => {
  'id': id,
  'title': 'Canlı Performans',
  'performerName': band ? 'Şahbaz' : 'Buğra',
  'performerType': band ? 'BAND' : 'MUSICIAN',
  'musicianProfileId': band ? null : 'artist',
  'bandId': band ? 'band' : null,
  'eventDate': '2026-09-06',
  'startTime': '21:00:00',
  'endTime': null,
  'venueId': 'venue',
  'venueName': 'SoundConnect Ankara',
  'posterImage': null,
};

class _CalendarApi extends ApiClient {
  Object? value;
  Future<Object?>? pending;
  int calls = 0;
  String? path;
  Object? body;
  Map<String, dynamic>? query;
  ApiRequestContext? context;
  ApiHttpMethod? method;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
  }) async {
    calls++;
    this.path = path;
    this.query = query;
    return decoder!(pending == null ? value : await pending!);
  }

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.body = body;
    context = requestContext;
    return decoder!(pending == null ? value : await pending!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
