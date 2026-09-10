import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_profile_share_repository_impl.dart';

import 'support/event_audience_fakes.dart';

void main() {
  test(
    'bounded public lookup is fenced and rejects unrequested or duplicate rows',
    () async {
      final h = _Harness(session: audienceSession(role: 'ROLE_MUSICIAN'));
      h.api.reply = [_post()];
      final result = await h.repository.lookupProfile(
        profileId: 'profile',
        expectedSession: h.session,
        shareIds: {'publication', 'deleted'},
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.single.tableGroup.acceptedCount, 2);
      expect(
        h.api.requests.single.path,
        '/api/v1/public/listener-profiles/profile/table-group-posts/lookup',
      );
      expect(h.api.requests.single.query, {'shareIds': 'publication,deleted'});
      expect(h.api.requests.single.context!.expectedToken, h.session.token);
      expect(h.repository.changes.value, 0);
      for (final invalid in [
        [_post(), _post()],
        [
          {..._post(), 'shareId': 'unrequested'},
        ],
        {
          'content': [_post()],
        },
      ]) {
        h.api.reply = invalid;
        expect(
          (await h.repository.lookupProfile(
            profileId: 'profile',
            expectedSession: h.session,
            shareIds: {'publication'},
          )).isSuccess,
          isFalse,
        );
      }
      h.api.reply = [];
      expect(
        (await h.repository.lookupProfile(
          profileId: 'profile',
          expectedSession: h.session,
          shareIds: {'publication'},
        )).data,
        isEmpty,
      );
      final requests = h.api.requests.length;
      for (final ids in [
        <String>{},
        Set<String>.from(List.generate(51, (i) => 'share-$i')),
      ]) {
        expect(
          (await h.repository.lookupProfile(
            profileId: 'profile',
            expectedSession: h.session,
            shareIds: ids,
          )).isSuccess,
          isFalse,
        );
      }
      expect(h.api.requests, hasLength(requests));
    },
  );

  test(
    'late lookup response cannot cross an exact session replacement',
    () async {
      final h = _Harness();
      h.api.pending = Completer<Object?>();
      final reading = h.repository.lookupProfile(
        profileId: 'profile',
        expectedSession: h.session,
        shareIds: {'publication'},
      );
      h.sessions.replace(audienceSession(token: 'replacement'));
      h.api.pending!.complete([_post()]);
      expect(
        (await reading).error?.code,
        'table_group_profile_share_session_changed',
      );
    },
  );

  test(
    'profile publication uses its own identity and fenced transport',
    () async {
      final h = _Harness();
      h.api.reply = _state();
      final result = await h.repository.publish(
        tableGroupId: 'table',
        note: '  Beraber müzik 🎵  ',
        expectedSession: h.session,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.tableGroup!.acceptedCount, 2);
      expect(result.data!.tableGroupId, 'table');
      final request = h.api.requests.single;
      expect(request.method, ApiHttpMethod.put);
      expect(request.path, '/api/v1/table-groups/table/profile-share');
      expect(request.body, {'note': 'Beraber müzik 🎵'});
      expect(request.context?.expectedSessionKey, h.session.userId);
      expect(request.context?.expectedToken, h.session.token);
      expect(h.repository.changes.value, 1);

      h.api.reply = null;
      expect(
        (await h.repository.deleteShare(
          shareId: 'publication',
          expectedSession: h.session,
        )).isSuccess,
        isTrue,
      );
      expect(
        h.api.requests.last.path,
        '/api/v1/table-groups/profile-shares/publication',
      );
    },
  );

  test(
    'public reads allow active viewers while writes require listener role',
    () async {
      final h = _Harness(session: audienceSession(role: 'ROLE_MUSICIAN'));
      h.api.reply = _page();
      final list = await h.repository.listProfile(
        profileId: 'profile',
        expectedSession: h.session,
        page: 2,
      );
      expect(list.isSuccess, isTrue);
      expect(list.data!.items.single.shareId, 'publication');
      expect(list.data!.items.single.likeCount, 4);
      expect(list.data!.items.single.commentCount, 7);
      expect(list.data!.items.single.likedByMe, isTrue);
      expect(h.api.requests.single.query, {'page': 2, 'size': 20});
      expect(
        h.api.requests.single.path,
        '/api/v1/public/listener-profiles/profile/table-group-posts',
      );
      expect(
        (await h.repository.publish(
          tableGroupId: 'table',
          expectedSession: h.session,
        )).isSuccess,
        isFalse,
      );
      expect(h.api.requests, hasLength(1));
    },
  );

  test('source identity and lifecycle projection are authoritative', () async {
    final h = _Harness();
    h.api.reply = {
      ..._state(),
      'canPublish': false,
      'tableGroup': {..._source(), 'status': 'INACTIVE'},
    };
    final ended = await h.repository.getState(
      tableGroupId: 'table',
      expectedSession: h.session,
    );
    expect(ended.isSuccess, isTrue);
    expect(ended.data!.publishedOnProfile, isTrue);
    expect(ended.data!.canPublish, isFalse);
    expect(ended.data!.tableGroup!.status, 'INACTIVE');

    for (final invalid in [
      {..._state(), 'tableGroupId': 'different'},
      {
        ..._state(),
        'tableGroup': {..._source(), 'id': 'different'},
      },
      {..._state(), 'tableGroup': null},
      {..._state(), 'shareId': null},
      {..._state(), 'publishedAt': '2026-09-10T12:00:00'},
      {
        ..._state(),
        'tableGroup': {..._source(), 'acceptedCount': 5},
      },
      {
        ..._state(),
        'tableGroup': {..._source(), 'maxPersonCount': 0},
      },
      {
        ..._state(),
        'tableGroup': {..._source(), 'description': null},
      },
      {
        ..._state(),
        'tableGroup': {..._source(), 'description': '  '},
      },
      {
        ..._state(),
        'tableGroup': {..._source(), 'meetingAt': null},
      },
      {
        ..._state(),
        'tableGroup': {..._source(), 'expiresAt': null},
      },
      {
        ..._state(),
        'tableGroup': {..._source(), 'status': 'INACTIVE'},
      },
      {
        ..._state(),
        'canPublish': false,
        'tableGroup': {..._source(), 'status': 'CANCELLED', 'meetingAt': null},
      },
    ]) {
      h.api.reply = invalid;
      final result = await h.repository.getState(
        tableGroupId: 'table',
        expectedSession: h.session,
      );
      expect(result.isSuccess, isFalse, reason: '$invalid');
      expect(result.data, isNull);
    }
  });

  test(
    'ended profile cards retain their final preview and publication identity',
    () async {
      final h = _Harness();
      for (final status in ['INACTIVE', 'CANCELLED']) {
        h.api.reply = {
          ..._page(),
          'content': [
            {
              ..._post(),
              'note': 'Masadan kalan bir anı',
              'tableGroup': {
                ..._source(),
                'status': status,
                'acceptedCount': 3,
              },
            },
          ],
        };
        final result = await h.repository.listProfile(
          profileId: 'profile',
          expectedSession: h.session,
          page: 2,
        );
        expect(result.isSuccess, isTrue);
        final share = result.data!.items.single;
        expect(share.shareId, 'publication');
        expect(share.publishedAt, DateTime.utc(2026, 9, 10, 12));
        expect(share.note, 'Masadan kalan bir anı');
        expect(share.tableGroup.status, status);
        expect(share.tableGroup.acceptedCount, 3);
        expect(share.likeCount, 4);
        expect(share.commentCount, 7);
        expect(share.likedByMe, isTrue);
      }
    },
  );

  test(
    'malformed pages fail atomically and invalid arguments never dispatch',
    () async {
      final h = _Harness();
      for (final invalid in [
        {..._page(), 'number': 0},
        {
          ..._page(),
          'content': [_post(), _post()],
        },
        {
          ..._page(),
          'content': [
            {..._post(), 'likeCount': -1},
          ],
        },
        {
          ..._page(),
          'content': [
            {..._post(), 'likedByMe': 'true'},
          ],
        },
      ]) {
        h.api.reply = invalid;
        expect(
          (await h.repository.listProfile(
            profileId: 'profile',
            expectedSession: h.session,
            page: 2,
          )).isSuccess,
          isFalse,
        );
      }
      h.api.requests.clear();
      for (final invalidId in ['', '../another', ' table']) {
        await h.repository.getState(
          tableGroupId: invalidId,
          expectedSession: h.session,
        );
      }
      await h.repository.publish(
        tableGroupId: 'table',
        note: List.filled(501, '🎵').join(),
        expectedSession: h.session,
      );
      await h.repository.listProfile(
        profileId: 'profile',
        expectedSession: h.session,
        size: 51,
      );
      expect(h.api.requests, isEmpty);
      expect(h.repository.changes.value, 0);
    },
  );

  for (final code in ['network', '9132']) {
    test('uncertain $code mutation revalidates after reconciliation', () async {
      final h = _Harness();
      h.api.error = AppError(code: code, message: 'Response unavailable');
      expect(
        (await h.repository.publish(
          tableGroupId: 'table',
          note: 'Beraber müzik 🎵',
          expectedSession: h.session,
        )).isSuccess,
        isFalse,
      );
      expect(h.repository.changes.value, 1);
      h.api.error = null;
      h.api.reply = _state();
      await h.repository.getState(
        tableGroupId: 'table',
        expectedSession: h.session,
      );
      expect(h.repository.changes.value, 2);
      expect(
        h.api.requests.where((r) => r.method == ApiHttpMethod.put),
        hasLength(1),
      );
    });
  }

  test(
    'definitive membership denial never claims a local publication',
    () async {
      final h = _Harness();
      h.api.error = const AppError(code: '9133', message: 'Katılımcı değilsin');
      final result = await h.repository.publish(
        tableGroupId: 'table',
        expectedSession: h.session,
      );
      expect(result.error?.code, '9133');
      expect(h.repository.changes.value, 0);
    },
  );

  test(
    'logout and same-user relogin fence pending writes and observers',
    () async {
      final h = _Harness();
      final original = h.session;
      h.api.pending = Completer<Object?>();
      final write = h.repository.publish(
        tableGroupId: 'table',
        note: 'Beraber müzik 🎵',
        expectedSession: original,
      );
      h.sessions.replace(audienceSession(token: 'new-token'));
      h.api.pending!.complete(_state());
      expect(
        (await write).error?.code,
        'table_group_profile_share_session_changed',
      );
      expect(h.repository.changes.value, 0);
      final stale = await h.repository.getState(
        tableGroupId: 'table',
        expectedSession: original,
      );
      expect(stale.isSuccess, isFalse);
      expect(h.api.requests, hasLength(1));
    },
  );
}

Map<String, Object?> _source() => {
  'id': 'table',
  'description': 'Müzik konuşalım',
  'venueName': null,
  'cityName': 'Ankara',
  'districtName': 'Çankaya',
  'meetingAt': '2026-09-10T18:00:00Z',
  'expiresAt': '2026-09-11T18:00:00Z',
  'status': 'ACTIVE',
  'maxPersonCount': 4,
  'acceptedCount': 2,
};

Map<String, Object?> _state() => {
  'tableGroupId': 'table',
  'shareId': 'publication',
  'publishedOnProfile': true,
  'note': 'Beraber müzik 🎵',
  'publishedAt': '2026-09-10T12:00:00Z',
  'canPublish': true,
  'tableGroup': _source(),
};

Map<String, Object?> _post() => {
  'shareId': 'publication',
  'note': null,
  'publishedAt': '2026-09-10T12:00:00Z',
  'tableGroup': _source(),
  'likeCount': 4,
  'commentCount': 7,
  'likedByMe': true,
};

Map<String, Object?> _page() => {
  'number': 2,
  'last': false,
  'content': [_post()],
};

typedef _Request = ({
  ApiHttpMethod method,
  String path,
  Object? body,
  Map<String, dynamic>? query,
  ApiRequestContext? context,
});

class _Api extends Fake implements ApiClient {
  final requests = <_Request>[];
  Object? reply;
  AppError? error;
  Completer<Object?>? pending;

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    requests.add((
      method: method,
      path: path,
      body: body,
      query: query,
      context: requestContext,
    ));
    if (error != null) throw ApiException(error!);
    final raw = pending == null ? reply : await pending!.future;
    return decoder == null ? raw as T : decoder(raw);
  }
}

class _Harness {
  _Harness({AuthSession? session}) {
    sessions = AudienceTestSessions(session ?? audienceSession());
    repository = TableGroupProfileShareRepositoryImpl(api, sessions: sessions);
    addTearDown(() {
      repository.dispose();
      sessions.dispose();
    });
  }

  final api = _Api();
  late final AudienceTestSessions sessions;
  late final TableGroupProfileShareRepositoryImpl repository;
  AuthSession get session => sessions.session;
}
