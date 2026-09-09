import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/data/event_audience_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';

import 'support/event_audience_fakes.dart';

void main() {
  test(
    'private current intent uses captured session and strict event scope',
    () async {
      final api = _Api()..response = _state();
      final repository = EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener',
      );
      final result = await repository.getIntent(
        eventId: audienceEventId,
        expectedSessionKey: 'listener',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.intent, EventAudienceStatus.none);
      expect(result.data!.updatedAt, isNull);
      expect(api.path, '/api/v1/user/event-intents/$audienceEventId');
      expect(api.context!.expectedSessionKey, 'listener');
    },
  );

  test(
    'full command serializes explicit note null and notifies only confirmed writes',
    () async {
      final api = _Api()..response = _state(intent: 'GOING', version: 1);
      final repository = EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener',
      );
      final result = await repository.setIntent(
        eventId: audienceEventId,
        intent: EventAudienceStatus.going,
        publishedOnProfile: false,
        note: null,
        expectedVersion: 0,
        expectedSessionKey: 'listener',
      );
      expect(result.isSuccess, isTrue);
      expect(api.method, ApiHttpMethod.put);
      expect(api.body, {
        'intent': 'GOING',
        'publishedOnProfile': false,
        'note': null,
        'expectedVersion': 0,
      });
      expect(repository.changes.value, 1);
    },
  );

  test(
    'profile publication trims note and preserves chosen status/version',
    () async {
      final api = _Api()
        ..response = _state(
          intent: 'THINKING',
          version: 2,
          published: true,
          note: 'Görüşürüz',
        );
      final repository = EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener',
      );
      final result = await repository.setIntent(
        eventId: audienceEventId,
        intent: EventAudienceStatus.thinking,
        publishedOnProfile: true,
        note: ' Görüşürüz ',
        expectedVersion: 1,
        expectedSessionKey: 'listener',
      );
      expect(result.isSuccess, isTrue);
      expect((api.body as Map)['note'], 'Görüşürüz');
      expect(result.data!.postId, audiencePostId);
      expect(result.data!.postId, isNot(result.data!.eventId));
    },
  );

  for (final change in <Map<String, dynamic>>[
    {'eventId': audienceVenueId},
    {'intent': 'MAYBE'},
    {'publishedOnProfile': 'false'},
    {'canSetIntent': 1},
    {'eventEnded': true},
    {'canPublish': 'true'},
    {'eventAvailable': false},
    {'event': null},
    {'publicationVisible': true},
    {'version': -1},
    {'version': 1, 'updatedAt': null},
    {'note': 'private note'},
    {'publishedOnProfile': true},
    {'updatedAt': '2026-09-08'},
    {
      'event': {..._event(), 'id': audienceVenueId},
    },
    {
      'event': {..._event(), 'eventDate': '2026-02-30'},
    },
  ]) {
    test(
      'malformed or inconsistent private projection fails: $change',
      () async {
        final api = _Api()..response = {..._state(), ...change};
        final result = await EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        ).getIntent(eventId: audienceEventId, expectedSessionKey: 'listener');
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      },
    );
  }

  for (final args in [
    (EventAudienceStatus.none, true, null),
    (EventAudienceStatus.going, false, 'not private'),
    (EventAudienceStatus.thinking, true, List.filled(501, '😀').join()),
  ]) {
    test(
      'invalid publication command never reaches network ${args.$1}',
      () async {
        final api = _Api();
        final result =
            await EventAudienceRepositoryImpl(
              api,
              sessionKeyProvider: () => 'listener',
            ).setIntent(
              eventId: audienceEventId,
              intent: args.$1,
              publishedOnProfile: args.$2,
              note: args.$3,
              expectedVersion: 0,
              expectedSessionKey: 'listener',
            );
        expect(result.isSuccess, isFalse);
        expect(api.calls, 0);
      },
    );
  }

  test('500 Unicode code points pass without UTF16 truncation', () async {
    final note = List.filled(500, '😀').join();
    final api = _Api()
      ..response = _state(
        intent: 'GOING',
        version: 1,
        published: true,
        note: note,
      );
    final result =
        await EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        ).setIntent(
          eventId: audienceEventId,
          intent: EventAudienceStatus.going,
          publishedOnProfile: true,
          note: note,
          expectedVersion: 0,
          expectedSessionKey: 'listener',
        );
    expect(result.isSuccess, isTrue);
    expect((api.body as Map)['note'], note);
  });

  for (final change in [
    {'intent': 'THINKING'},
    {'version': 9},
    {'publishedOnProfile': true},
  ]) {
    test(
      'unconfirmed desired mutation never publishes an invalidation $change',
      () async {
        final api = _Api()
          ..response = {..._state(intent: 'GOING', version: 1), ...change};
        final repository = EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        );
        final result = await repository.setIntent(
          eventId: audienceEventId,
          intent: EventAudienceStatus.going,
          publishedOnProfile: false,
          note: null,
          expectedVersion: 0,
          expectedSessionKey: 'listener',
        );
        expect(result.isSuccess, isFalse);
        expect(repository.changes.value, 0);
      },
    );
  }

  test(
    'session switch before request is blocked and late response is discarded',
    () async {
      var actor = 'other';
      final api = _Api()..response = _state();
      final repository = EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => actor,
      );
      expect(
        (await repository.getIntent(
          eventId: audienceEventId,
          expectedSessionKey: 'listener',
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, 0);
      actor = 'listener';
      final pending = Completer<Object?>();
      api.pending = pending.future;
      final reading = repository.getIntent(
        eventId: audienceEventId,
        expectedSessionKey: 'listener',
      );
      actor = 'other';
      pending.complete(_state());
      expect((await reading).isSuccess, isFalse);
    },
  );

  test('conflict is surfaced once without mutation retry', () async {
    final api = _Api()
      ..error = ApiException(const AppError(code: '9921', message: 'reload'));
    final result =
        await EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        ).setIntent(
          eventId: audienceEventId,
          intent: EventAudienceStatus.going,
          publishedOnProfile: false,
          note: null,
          expectedVersion: 0,
          expectedSessionKey: 'listener',
        );
    expect(result.error!.code, '9921');
    expect(api.calls, 1);
  });

  test(
    'mine and public pages use server periods and bounded strict pagination',
    () async {
      final api = _Api()..response = _page(_state(intent: 'GOING', version: 1));
      final repository = EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener',
      );
      final mine = await repository.listMine(
        expectedSessionKey: 'listener',
        period: EventAudiencePeriod.past,
      );
      expect(mine.isSuccess, isTrue);
      expect(mine.data!.items.single.intent, EventAudienceStatus.going);
      expect(api.query, {'period': 'PAST', 'page': 0, 'size': 20});
      api.response = _page({
        'eventId': audienceEventId,
        'postId': audiencePostId,
        'intent': 'THINKING',
        'note': 'Belki',
        'publishedAt': '2026-09-08T12:00:00Z',
        'eventEnded': true,
        'event': _event(),
      });
      final posts = await repository.listPublic(
        audienceVenueId,
        expectedSessionKey: 'listener',
      );
      expect(posts.isSuccess, isTrue);
      expect(posts.data!.items.single.eventEnded, isTrue);
      expect(posts.data!.items.single.postId, audiencePostId);
      expect(posts.data!.items.single.eventId, audienceEventId);
      expect(api.query!['period'], 'ALL');
      expect(api.context!.expectedSessionKey, 'listener');
    },
  );

  for (final change in [
    {'first': false},
    {'last': false},
    {'number': 1},
    {'totalElements': 2},
    {'size': 0},
    {'content': []},
    {
      'content': [_state(intent: 'GOING'), _state(intent: 'GOING')],
      'totalElements': 2,
    },
  ]) {
    test('invalid audience page fails $change', () async {
      final api = _Api()
        ..response = {..._page(_state(intent: 'GOING', version: 1)), ...change};
      final result = await EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener',
      ).listMine(expectedSessionKey: 'listener');
      expect(result.isSuccess, isFalse);
    });
  }

  for (final malformedId in <Object?>[
    null,
    '',
    'event/not-a-publication',
    4,
    '00000000-0000-0000-0000-000000000000',
  ]) {
    test(
      'public publication never falls back to eventId: $malformedId',
      () async {
        final api = _Api()
          ..response = _page({..._post(), 'postId': malformedId});
        final result = await EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        ).listPublic(audienceVenueId, expectedSessionKey: 'listener');
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      },
    );
  }

  test('legacy publication missing post identity is not actionable', () async {
    final post = _post()..remove('postId');
    final api = _Api()..response = _page(post);
    final result = await EventAudienceRepositoryImpl(
      api,
      sessionKeyProvider: () => 'listener',
    ).listPublic(audienceVenueId, expectedSessionKey: 'listener');
    expect(result.isSuccess, isFalse);
  });

  for (final published in [false, true]) {
    test(
      'private state rejects inconsistent publication identity ($published)',
      () async {
        final api = _Api()
          ..response = {
            ..._state(intent: 'GOING', version: 1, published: published),
            'postId': published ? null : audiencePostId,
          };
        final result = await EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        ).getIntent(eventId: audienceEventId, expectedSessionKey: 'listener');
        expect(result.isSuccess, isFalse);
      },
    );
  }

  test('hidden publication retains its independent identity', () async {
    final api = _Api()
      ..response = {
        ..._state(intent: 'GOING', version: 1, published: true),
        'publicationVisible': false,
      };
    final result = await EventAudienceRepositoryImpl(
      api,
      sessionKeyProvider: () => 'listener',
    ).getIntent(eventId: audienceEventId, expectedSessionKey: 'listener');
    expect(result.isSuccess, isTrue);
    expect(result.data!.postId, audiencePostId);
    expect(result.data!.publicationVisible, isFalse);
  });

  test('duplicate post identity invalidates the public page', () async {
    final api = _Api()
      ..response = {
        ..._page(_post()),
        'content': [
          _post(),
          {
            ..._post(),
            'eventId': audienceVenueId,
            'event': {..._event(), 'id': audienceVenueId},
          },
        ],
        'totalElements': 2,
      };
    final result = await EventAudienceRepositoryImpl(
      api,
      sessionKeyProvider: () => 'listener',
    ).listPublic(audienceVenueId, expectedSessionKey: 'listener');
    expect(result.isSuccess, isFalse);
  });

  test(
    'delete targets post UUID, preserves returned plan and invalidates once',
    () async {
      final api = _Api()..response = _state(intent: 'GOING', version: 3);
      final repository = EventAudienceRepositoryImpl(
        api,
        sessionKeyProvider: () => 'listener',
      );
      final result = await repository.deletePost(
        postId: audiencePostId,
        expectedSessionKey: 'listener',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.intent, EventAudienceStatus.going);
      expect(result.data!.eventId, audienceEventId);
      expect(result.data!.postId, isNull);
      expect(result.data!.publishedOnProfile, isFalse);
      expect(result.data!.note, isNull);
      expect(result.data!.version, 3);
      expect(api.path, '/api/v1/user/event-posts/$audiencePostId');
      expect(api.method, ApiHttpMethod.delete);
      expect(api.body, isNull);
      expect(api.context!.expectedSessionKey, 'listener');
      expect(api.calls, 1);
      expect(repository.changes.value, 1);
    },
  );

  for (final error in [
    const AppError(code: '404', message: 'Post no longer exists'),
    const AppError(code: 'network', message: 'Disconnected'),
  ]) {
    test(
      'failed post deletion is surfaced without retry or invalidation: ${error.code}',
      () async {
        final api = _Api()..error = ApiException(error);
        final repository = EventAudienceRepositoryImpl(
          api,
          sessionKeyProvider: () => 'listener',
        );
        final result = await repository.deletePost(
          postId: audiencePostId,
          expectedSessionKey: 'listener',
        );
        expect(result.error, same(error));
        expect(api.calls, 1);
        expect(repository.changes.value, 0);
      },
    );
  }

  test('invalid deletion identity never reaches the transport', () async {
    final api = _Api();
    final repository = EventAudienceRepositoryImpl(
      api,
      sessionKeyProvider: () => 'listener',
    );
    final result = await repository.deletePost(
      postId: '../event-intents/$audienceEventId',
      expectedSessionKey: 'listener',
    );
    expect(result.isSuccess, isFalse);
    expect(api.calls, 0);
    expect(repository.changes.value, 0);
  });

  test('unconfirmed deletion cannot announce success or reload', () async {
    final api = _Api()
      ..response = _state(intent: 'GOING', version: 3, published: true);
    final repository = EventAudienceRepositoryImpl(
      api,
      sessionKeyProvider: () => 'listener',
    );
    final result = await repository.deletePost(
      postId: audiencePostId,
      expectedSessionKey: 'listener',
    );
    expect(result.isSuccess, isFalse);
    expect(repository.changes.value, 0);
  });

  test('session switch fences deletion before and after transport', () async {
    var actor = 'other';
    final api = _Api();
    final repository = EventAudienceRepositoryImpl(
      api,
      sessionKeyProvider: () => actor,
    );
    final rejected = await repository.deletePost(
      postId: audiencePostId,
      expectedSessionKey: 'listener',
    );
    expect(rejected.error!.code, 'event_audience_session_changed');
    expect(api.calls, 0);
    actor = 'listener';
    final pending = Completer<Object?>();
    api.pending = pending.future;
    final deleting = repository.deletePost(
      postId: audiencePostId,
      expectedSessionKey: 'listener',
    );
    actor = 'other';
    pending.complete(_state(intent: 'GOING', version: 3));
    final late = await deleting;
    expect(late.error!.code, 'event_audience_session_changed');
    expect(late.data, isNull);
    expect(repository.changes.value, 0);
    expect(api.calls, 1);
  });
}

Map<String, dynamic> _post() => {
  'eventId': audienceEventId,
  'postId': audiencePostId,
  'intent': 'GOING',
  'note': 'Görüşürüz',
  'publishedAt': '2026-09-08T12:00:00Z',
  'eventEnded': false,
  'event': _event(),
};

Map<String, dynamic> _state({
  String intent = 'NONE',
  int version = 0,
  bool published = false,
  String? note,
}) => {
  'eventId': audienceEventId,
  'postId': published ? audiencePostId : null,
  'intent': intent,
  'publishedOnProfile': published,
  'note': note,
  'version': version,
  'updatedAt': version == 0 ? null : '2026-09-08T12:00:00Z',
  'eventAvailable': true,
  'eventEnded': false,
  'canSetIntent': true,
  'canPublish': true,
  'publicationVisible': published,
  'event': _event(),
};
Map<String, dynamic> _event() => {
  'id': audienceEventId,
  'title': 'Canlı müzik akşamı',
  'eventDate': '2026-09-09',
  'venueId': audienceVenueId,
  'venueName': 'SoundConnect Ankara',
  'performerType': 'MANUAL',
  'performerName': 'Sanatçı',
};
Map<String, dynamic> _page(Object row) => {
  'content': [row],
  'page': 0,
  'number': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'first': true,
  'last': true,
};

class _Api extends Fake implements ApiClient {
  Object? response;
  Future<Object?>? pending;
  Object? error;
  int calls = 0;
  String? path;
  Object? body;
  ApiHttpMethod? method;
  Map<String, dynamic>? query;
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
    calls++;
    this.path = path;
    this.body = body;
    this.method = method;
    this.query = query;
    context = requestContext;
    if (error != null) throw error!;
    return decoder!(pending == null ? response : await pending!);
  }
}
