import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_plan_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_plan.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';

Map<String, dynamic> planJson({int version = 0}) => {
  'id': 'plan-1',
  'version': version,
  'definition': {
    'venueId': 'venue-1',
    'startDate': '2026-09-21',
    'untilDate': null,
    'weekdays': [1, 5],
    'excludedDates': <String>[],
    'template': {
      'title': 'Akustik Akşamlar',
      'description': 'Canlı müzik',
      'startTime': '20:00:00',
      'endTime': '22:00:00',
      'posterImage': 'raw-asset-id',
      'musicianProfileId': 'musician-1',
      'bandId': null,
      'manualPerformerName': null,
    },
  },
  'venueName': 'Ankara Sahne',
  'performerName': 'Deniz',
  'posterUrl': 'https://example.test/resolved.jpg',
  'status': 'ACTIVE',
  'consentStatus': 'PENDING',
  'showOnProfile': false,
  'generatedThrough': '2026-10-18',
  'serverNow': '2026-09-21T10:00:00Z',
  'decisionAllowed': true,
  'withdrawAllowed': false,
};

void main() {
  late _Api api;
  late EventPlanRepositoryImpl repo;
  String? user = 'owner', token = 'token';
  var changes = 0;
  setUp(() {
    api = _Api();
    user = 'owner';
    token = 'token';
    changes = 0;
    repo = EventPlanRepositoryImpl(
      api,
      sessionKeyProvider: () => user,
      tokenProvider: () => token,
      onChanged: () => changes++,
    );
  });
  test(
    'create preserves indefinite scope raw asset and replay identity',
    () async {
      api.value = planJson();
      final definition = EventPlanRepositoryImpl.decodePlan(
        planJson(),
      ).definition;
      final result = await repo.create('request-uuid', definition);
      expect(result.isSuccess, isTrue);
      expect(api.calls, 1);
      expect(api.body, {
        'clientRequestId': 'request-uuid',
        'definition': definition.toJson(),
      });
      expect((api.body as Map)['definition']['untilDate'], isNull);
      expect(
        (api.body as Map)['definition']['template']['posterImage'],
        'raw-asset-id',
      );
      expect(api.context!.expectedSessionKey, 'owner');
      expect(api.context!.expectedToken, 'token');
      expect(changes, 1);
    },
  );
  test(
    'same account relogin discards in-flight mutation and refresh callback',
    () async {
      final pending = Completer<Object?>();
      api.pending = pending.future;
      final plan = EventPlanRepositoryImpl.decodePlan(planJson());
      final request = repo.stop(plan, cancelFuture: true);
      token = 'new-token';
      pending.complete(planJson(version: 1));
      expect((await request).error!.code, 'event_plan_session_changed');
      expect(changes, 0);
    },
  );
  test('lost response never repeats write', () async {
    api.failure = StateError('lost reply');
    final result = await repo.create(
      'same-request',
      EventPlanRepositoryImpl.decodePlan(planJson()).definition,
    );
    expect(result.isSuccess, isFalse);
    expect(api.calls, 1);
    expect(changes, 0);
  });
  test('copy source keeps pending performer target and raw poster', () async {
    final json = planJson();
    api.value = <String, dynamic>{
      ...json['definition']['template'],
      'eventDate': '2026-09-22',
      'venueId': 'venue-1',
    };
    final result = await repo.copySource('event-1', 'venue-1');
    expect(result.data!.musicianProfileId, 'musician-1');
    expect(result.data!.posterImage, 'raw-asset-id');
    expect(api.path, '/api/v1/venue-owner/events/event-1/copy-source');
    expect(
      (await repo.copySource('event-1', 'other-venue')).isSuccess,
      isFalse,
    );
  });
  test('wrong plan identity and older versions fail closed', () async {
    final plan = EventPlanRepositoryImpl.decodePlan(planJson(version: 2));
    api.value = {...planJson(version: 3), 'id': 'different'};
    expect((await repo.stop(plan, cancelFuture: false)).isSuccess, isFalse);
    api.value = planJson(version: 1);
    expect((await repo.stop(plan, cancelFuture: false)).isSuccess, isFalse);
    expect(changes, 0);
  });
  test(
    'accept requires explicit publication and withdraw sends null',
    () async {
      final plan = EventPlanRepositoryImpl.decodePlan(planJson());
      api.value = planJson(version: 1);
      expect((await repo.decide(plan, 'ACCEPT')).isSuccess, isFalse);
      expect(api.calls, 0);
      await repo.decide(plan, 'ACCEPT', showOnProfile: false);
      expect(api.body, {
        'expectedVersion': 0,
        'decision': 'ACCEPT',
        'showOnProfile': false,
      });
      await repo.decide(plan, 'WITHDRAW');
      expect(api.body, {
        'expectedVersion': 0,
        'decision': 'WITHDRAW',
        'showOnProfile': null,
      });
    },
  );
  test('performer page rejects a different target and duplicates', () async {
    Map<String, dynamic> page(List<Object?> rows) => {
      'content': rows,
      'page': 0,
      'size': 20,
      'totalElements': rows.length,
      'totalPages': 1,
      'last': true,
    };
    api.value = page([planJson()]);
    expect(
      (await repo.listPerformer(
        EventPerformerTargetType.musician,
        'other',
      )).isSuccess,
      isFalse,
    );
    api.value = page([planJson(), planJson()]);
    expect(
      (await repo.listPerformer(
        EventPerformerTargetType.musician,
        'musician-1',
      )).isSuccess,
      isFalse,
    );
  });
  test(
    'today preview accepts a draft initialized with the current time',
    () async {
      final template = EventPlanRepositoryImpl.decodePlan(
        planJson(),
      ).definition.template;
      final definition = EventPlanDefinition(
        venueId: 'venue-1',
        startDate: DateTime(2026, 9, 22, 1, 50),
        untilDate: DateTime(2026, 10, 20, 1, 50),
        weekdays: [2],
        excludedDates: [],
        template: template,
      );
      api.value = {
        'dates': ['2026-09-22', '2026-09-29'],
        'throughDate': '2026-10-19',
        'hasMore': true,
        'serverNow': '2026-09-21T22:50:00Z',
      };
      final result = await repo.preview(definition);
      expect(result.isSuccess, isTrue, reason: result.error?.message);
      expect(result.data!.dates.map(eventPlanDate), [
        '2026-09-22',
        '2026-09-29',
      ]);
      expect((api.body as Map)['startDate'], '2026-09-22');
      expect((api.body as Map)['untilDate'], '2026-10-20');
    },
  );

  test(
    'plan calendar boundaries and exclusions discard incidental time and UTC offsets',
    () {
      final definition = EventPlanDefinition(
        venueId: 'venue-1',
        startDate: DateTime(2026, 9, 22, 1, 50),
        untilDate: DateTime.utc(2026, 9, 22, 23, 59),
        weekdays: [2],
        excludedDates: [DateTime.utc(2026, 9, 22, 20, 15)],
        template: EventPlanRepositoryImpl.decodePlan(
          planJson(),
        ).definition.template,
      );
      expect(definition.startDate, DateTime(2026, 9, 22));
      expect(definition.untilDate, DateTime(2026, 9, 22));
      expect(definition.excludedDates, [DateTime(2026, 9, 22)]);
      expect(
        definition.withExclusions([DateTime(2026, 9, 29, 12)]).excludedDates,
        [DateTime(2026, 9, 29)],
      );
    },
  );

  test('preview rejects dates outside weekdays range or exclusions', () async {
    final definition = EventPlanRepositoryImpl.decodePlan(
      planJson(),
    ).definition;
    api.value = {
      'dates': ['2026-09-22'],
      'throughDate': '2026-10-18',
      'hasMore': true,
      'serverNow': '2026-09-21T10:00:00Z',
    };
    expect((await repo.preview(definition)).isSuccess, isFalse);
    api.value = {
      'dates': ['2026-09-21'],
      'throughDate': '2026-10-18',
      'hasMore': true,
      'serverNow': '2026-09-21T10:00:00Z',
    };
    expect(
      (await repo.preview(
        definition.withExclusions([DateTime(2026, 9, 21)]),
      )).isSuccess,
      isFalse,
    );
    expect((await repo.preview(definition)).isSuccess, isTrue);
  });
  group('preview edit context and preserved dates', () {
    late EventPlanDefinition definition;

    Map<String, Object?> response({
      List<String> dates = const ['2026-09-21'],
    }) => {
      'dates': dates,
      'throughDate': '2026-10-18',
      'hasMore': true,
      'serverNow': '2026-09-21T10:00:00Z',
    };

    Map<String, Object?> preserved({
      String scheduledDate = '2026-09-25',
      String eventDate = '2026-09-26',
      String status = 'OVERRIDDEN',
    }) => {
      'scheduledDate': scheduledDate,
      'eventDate': eventDate,
      'status': status,
    };

    setUp(() {
      definition = EventPlanRepositoryImpl.decodePlan(planJson()).definition;
    });

    test('create keeps its endpoint and accepts the legacy response', () async {
      api.value = response();

      final result = await repo.preview(definition);

      expect(result.isSuccess, isTrue);
      expect(result.data!.preservedDates, isEmpty);
      expect(api.method, ApiHttpMethod.post);
      expect(api.path, '/api/v1/venue-owner/event-plans/preview');
      expect(api.body, definition.toJson());
      expect(api.calls, 1);
      expect(changes, 0);
    });

    test('edit encodes the plan id and sends the expected version', () async {
      api.value = {...response(), 'preservedDates': <Object?>[]};

      final result = await repo.preview(
        definition,
        planId: 'plan/a b?#',
        expectedVersion: 7,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.preservedDates, isEmpty);
      expect(api.method, ApiHttpMethod.post);
      expect(
        api.path,
        '/api/v1/venue-owner/event-plans/plan%2Fa%20b%3F%23/preview',
      );
      expect(api.body, {
        'expectedVersion': 7,
        'definition': definition.toJson(),
      });
      expect(api.context!.expectedSessionKey, 'owner');
      expect(api.context!.expectedToken, 'token');
      expect(api.calls, 1);
      expect(changes, 0);
    });

    test('incomplete edit context fails before making a request', () async {
      api.value = {...response(), 'preservedDates': <Object?>[]};

      final missingVersion = await repo.preview(definition, planId: 'plan-1');
      final missingPlan = await repo.preview(definition, expectedVersion: 7);

      expect(missingVersion.isSuccess, isFalse);
      expect(missingPlan.isSuccess, isFalse);
      expect(api.calls, 0);
      expect(changes, 0);
    });

    test('edit requires an explicit preserved dates list', () async {
      for (final raw in [
        response(),
        {...response(), 'preservedDates': null},
        {...response(), 'preservedDates': <String, Object?>{}},
        {...response(), 'preservedDates': 'not-a-list'},
      ]) {
        api.value = raw;
        final result = await repo.preview(
          definition,
          planId: 'plan-1',
          expectedVersion: 7,
        );
        expect(result.isSuccess, isFalse, reason: 'Invalid payload: $raw');
      }
      expect(changes, 0);
    });

    test(
      'preserved dates retain their actual dates outside the new scope',
      () async {
        final limitedDefinition = EventPlanDefinition(
          venueId: definition.venueId,
          startDate: definition.startDate,
          untilDate: DateTime(2026, 9, 25),
          weekdays: definition.weekdays,
          excludedDates: const [],
          template: definition.template,
        );
        api.value = {
          ...response(),
          'preservedDates': [
            preserved(scheduledDate: '2026-09-22', eventDate: '2026-11-03'),
            preserved(
              scheduledDate: '2026-09-04',
              eventDate: '2026-09-04',
              status: 'SKIPPED',
            ),
            preserved(
              scheduledDate: '2026-10-20',
              eventDate: '2026-10-20',
              status: 'CANCELLED',
            ),
            preserved(
              scheduledDate: '2026-09-20',
              eventDate: '2026-09-20',
              status: 'STARTED',
            ),
          ],
        };

        final result = await repo.preview(
          limitedDefinition,
          planId: 'plan-1',
          expectedVersion: 7,
        );

        expect(result.isSuccess, isTrue);
        final entries = result.data!.preservedDates;
        expect(entries, hasLength(4));
        expect(entries.map((entry) => entry.status), [
          'OVERRIDDEN',
          'SKIPPED',
          'CANCELLED',
          'STARTED',
        ]);
        expect(entries.first.scheduledDate, DateTime(2026, 9, 22));
        expect(entries.first.eventDate, DateTime(2026, 11, 3));
        expect(entries[1].scheduledDate, DateTime(2026, 9, 4));
        expect(entries[2].scheduledDate, DateTime(2026, 10, 20));
        expect(entries[3].scheduledDate, DateTime(2026, 9, 20));
      },
    );

    test(
      'a moved event may share an actual date with a new occurrence',
      () async {
        api.value = {
          ...response(),
          'preservedDates': [preserved(eventDate: '2026-09-21')],
        };

        final result = await repo.preview(
          definition,
          planId: 'plan-1',
          expectedVersion: 7,
        );

        expect(result.isSuccess, isTrue);
        expect(result.data!.dates.single, DateTime(2026, 9, 21));
        expect(
          result.data!.preservedDates.single.scheduledDate,
          DateTime(2026, 9, 25),
        );
        expect(
          result.data!.preservedDates.single.eventDate,
          DateTime(2026, 9, 21),
        );
      },
    );

    test(
      'preserved scheduled dates cannot overlap new dates or repeat',
      () async {
        final invalidLists = <List<Object?>>[
          [preserved(scheduledDate: '2026-09-21')],
          [preserved(), preserved(eventDate: '2026-09-27', status: 'SKIPPED')],
          [preserved(), preserved()],
        ];

        for (final entries in invalidLists) {
          api.value = {...response(), 'preservedDates': entries};
          final result = await repo.preview(
            definition,
            planId: 'plan-1',
            expectedVersion: 7,
          );
          expect(
            result.isSuccess,
            isFalse,
            reason: 'Invalid entries: $entries',
          );
        }
        expect(changes, 0);
      },
    );

    test(
      'preserved entries require valid dates and whitelisted status',
      () async {
        final invalidEntries = <Object?>[
          null,
          'not-an-object',
          <String, Object?>{},
          {'eventDate': '2026-09-26', 'status': 'OVERRIDDEN'},
          {'scheduledDate': '2026-09-25', 'status': 'OVERRIDDEN'},
          {'scheduledDate': '2026-09-25', 'eventDate': '2026-09-26'},
          preserved(scheduledDate: '2026-02-30'),
          preserved(scheduledDate: '25/09/2026'),
          preserved(eventDate: '2026-02-30'),
          preserved(eventDate: '2026-09-26T20:00:00Z'),
          preserved(status: 'GENERATED'),
          preserved(status: 'overridden'),
          preserved(status: 'UNKNOWN'),
        ];

        for (final entry in invalidEntries) {
          api.value = {
            ...response(),
            'preservedDates': [entry],
          };
          final result = await repo.preview(
            definition,
            planId: 'plan-1',
            expectedVersion: 7,
          );
          expect(result.isSuccess, isFalse, reason: 'Invalid entry: $entry');
        }
        expect(changes, 0);
      },
    );
  });
  test(
    'occurrence uses immutable scheduled date while changing event date',
    () async {
      api.value = planJson(version: 1);
      final plan = EventPlanRepositoryImpl.decodePlan(planJson());
      await repo.editOccurrence(
        plan,
        EventPlanOccurrence(
          scheduledDate: DateTime(2026, 9, 21),
          eventDate: DateTime(2026, 9, 23),
          status: 'OVERRIDDEN',
          eventId: 'event-1',
        ),
        eventDate: DateTime(2026, 9, 25),
        template: plan.definition.template,
      );
      expect(api.path, endsWith('/occurrences/2026-09-21'));
      expect((api.body as Map)['eventDate'], '2026-09-25');
    },
  );
}

class _Api extends Fake implements ApiClient {
  Object? value, body, failure;
  Future<Object?>? pending;
  String? path;
  ApiHttpMethod? method;
  ApiRequestContext? context;
  int calls = 0;
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
    if (failure != null) throw failure!;
    final raw = pending == null ? value : await pending;
    return decoder!(raw);
  }
}
