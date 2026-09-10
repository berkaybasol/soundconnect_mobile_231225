import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_profile_share_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';

import 'support/event_audience_fakes.dart';

void main() {
  group('listener profile share access', () {
    test(
      'normalizes real listener roles without treating Mainstage as listener',
      () {
        expect(
          canShareOverthinkingOnProfile(audienceSession(role: ' listener ')),
          isTrue,
        );
        expect(
          canShareOverthinkingOnProfile(audienceSession(role: 'ROLE_LISTENER')),
          isTrue,
        );
        expect(
          canShareOverthinkingOnProfile(audienceSession(role: 'ROLE_MUSICIAN')),
          isFalse,
        );
        expect(
          canShareOverthinkingOnProfile(audienceSession(role: 'MAINSTAGE')),
          isFalse,
        );
        for (final role in [
          'MUSICIAN',
          'ADMIN',
          'OWNER',
          'VENUE',
          'STUDIO',
          'BAND',
          'ORGANIZER',
          'PRODUCER',
        ]) {
          expect(
            canShareOverthinkingOnProfile(
              audienceSession(roles: ['ROLE_LISTENER', 'ROLE_$role']),
            ),
            isFalse,
            reason: role,
          );
        }
      },
    );

    test(
      'guest, incomplete choice, inactive, admin and missing identities fail closed',
      () {
        expect(canShareOverthinkingOnProfile(null), isFalse);
        expect(
          canShareOverthinkingOnProfile(const AuthSession.guest()),
          isFalse,
        );
        expect(
          canShareOverthinkingOnProfile(audienceSession(status: 'SUSPENDED')),
          isFalse,
        );
        expect(
          canShareOverthinkingOnProfile(audienceSession(isAdmin: true)),
          isFalse,
        );
        expect(
          canShareOverthinkingOnProfile(audienceSession(user: ' ')),
          isFalse,
        );
        final choice = AuthSession.authenticated(
          token: 'token',
          userId: 'listener',
          username: 'listener',
          accountStatus: 'ACTIVE',
          roles: ['ROLE_LISTENER'],
          permissions: [],
          expiresAt: DateTime.utc(2100),
          isAdmin: false,
          requiresListenerProfileChoice: true,
        );
        expect(canShareOverthinkingOnProfile(choice), isFalse);
      },
    );
  });

  group('profile share contract and invalidation', () {
    test(
      'lost publish response refreshes the profile again when later reconciliation confirms the commit',
      () async {
        final h = _Harness();
        var committed = false;
        h.api.handler = (request) {
          if (request.method == ApiHttpMethod.put) {
            throw ApiException(
              const AppError(code: 'network', message: 'Response lost'),
            );
          }
          if (request.path.endsWith('/profile-share')) {
            return _state(published: committed);
          }
          return {
            ..._page(),
            'number': 0,
            'last': true,
            'content': committed ? _page()['content'] : [],
          };
        };
        final profileReads = <Future<Result<Page<OverthinkingProfileShare>>>>[];
        h.repository.changes.addListener(() {
          profileReads.add(
            h.repository.listProfile(
              profileId: 'profile',
              expectedSession: h.session,
            ),
          );
        });
        final write = await h.repository.publish(
          postId: 'source',
          note: 'My note',
          expectedSession: h.session,
        );
        expect(write.isSuccess, isFalse);
        expect((await profileReads.single).data!.items, isEmpty);
        // The transaction finishes after the first reload. The explicit status
        // check must wake the mounted profile list once more, without another PUT.
        committed = true;
        expect(
          (await h.repository.getState(
            postId: 'source',
            expectedSession: h.session,
          )).data!.publishedOnProfile,
          isTrue,
        );
        expect(profileReads, hasLength(2));
        expect((await profileReads.last).data!.items.single.shareId, 'share');
        expect(
          h.api.requests.where(
            (request) => request.method == ApiHttpMethod.put,
          ),
          hasLength(1),
        );
      },
    );

    for (final code in ['network', '408', '500', '9416']) {
      test(
        'ambiguous delete $code invalidates only its current account',
        () async {
          final h = _Harness();
          h.api.error = AppError(code: code, message: 'Uncertain result');
          expect(
            (await h.repository.deleteShare(
              shareId: 'share',
              expectedSession: h.session,
            )).isSuccess,
            isFalse,
          );
          expect(h.repository.changes.value, 1);
          h.sessions.replace(audienceSession(user: 'next', token: 'new'));
          h.api.error = null;
          h.api.reply = _state(published: false);
          await h.repository.getState(
            postId: 'source',
            expectedSession: h.session,
          );
          expect(h.repository.changes.value, 1);
        },
      );
    }

    test(
      'late ambiguous failure after a session change never invalidates the new profile',
      () async {
        final h = _Harness();
        final pending = Completer<Object?>();
        h.api.pending = pending;
        final write = h.repository.publish(
          postId: 'source',
          expectedSession: h.session,
        );
        h.sessions.replace(audienceSession(user: 'other', token: 'next'));
        pending.completeError(
          ApiException(
            const AppError(code: 'network', message: 'Response lost'),
          ),
        );
        expect((await write).isSuccess, isFalse);
        expect(h.repository.changes.value, 0);
      },
    );

    test(
      'state and list reads preserve viewer projection without emitting a write signal',
      () async {
        final h = _Harness();
        h.api.reply = _state(published: false, canPublish: false);
        final state = await h.repository.getState(
          postId: 'source',
          expectedSession: h.session,
        );
        expect(state.data!.canPublish, isFalse);
        expect(state.data!.publishedOnProfile, isFalse);
        h.api.reply = _page();
        final page = await h.repository.listProfile(
          profileId: 'profile',
          expectedSession: h.session,
          page: 2,
          size: 8,
        );
        expect(h.api.requests.last.query, {'page': 2, 'size': 8});
        expect(page.data!.hasNext, isTrue);
        expect(page.data!.nextCursor, '3');
        final row = page.data!.items.single;
        expect(row.shareId, 'share');
        expect(row.note, 'My note');
        expect(row.publishedAt, DateTime.utc(2026, 9, 10, 12));
        expect(row.post.id, 'source');
        expect(row.post.hasVisibleAuthor, isFalse);
        expect(row.post.authorId, isNull);
        expect(row.post.revealRequestPending, isTrue);
        expect(row.post.spotifyTrackName, 'Song');
        expect(h.repository.changes.value, 0);
      },
    );

    test(
      'publish normalizes the note and invalidates only after a confirmed response',
      () async {
        final h = _Harness();
        final pending = Completer<Object?>();
        h.api.pending = pending;
        final publish = h.repository.publish(
          postId: 'source',
          note: '  My note  ',
          expectedSession: h.session,
        );
        expect(h.api.requests.single.method, ApiHttpMethod.put);
        expect(
          h.api.requests.single.path,
          '/api/v1/overthinking/source/profile-share',
        );
        expect(h.api.requests.single.body, {'note': 'My note'});
        expect(h.repository.changes.value, 0);
        pending.complete(_state());
        final result = await publish;
        expect(result.data!.shareId, 'share');
        expect(h.repository.changes.value, 1);
      },
    );

    test(
      'exact share deletion sends no source id and never retries a stale card conflict',
      () async {
        final h = _Harness();
        h.api.reply = null;
        final deleted = await h.repository.deleteShare(
          shareId: 'old-share',
          expectedSession: h.session,
        );
        expect(deleted.isSuccess, isTrue);
        expect(h.api.requests.single.method, ApiHttpMethod.delete);
        expect(
          h.api.requests.single.path,
          '/api/v1/overthinking/profile-shares/old-share',
        );
        expect(h.repository.changes.value, 1);
        const error = AppError(code: '9415', message: 'Share not found');
        h.api.error = error;
        expect(
          (await h.repository.deleteShare(
            shareId: 'old-share',
            expectedSession: h.session,
          )).error,
          same(error),
        );
        expect(h.api.requests, hasLength(2));
        expect(h.repository.changes.value, 1);
      },
    );

    test(
      'immutable-note conflict is preserved without replacing the existing share',
      () async {
        final h = _Harness();
        const error = AppError(code: '9413', message: 'Already published');
        h.api.error = error;
        final result = await h.repository.publish(
          postId: 'source',
          note: 'Different note',
          expectedSession: h.session,
        );
        expect(result.error, same(error));
        expect(h.api.requests, hasLength(1));
        expect(h.repository.changes.value, 0);
      },
    );

    for (final malformed in [
      {..._state(), 'postId': 'different'},
      {..._state(), 'shareId': null},
      {..._state(), 'publishedAt': null},
      {..._state(), 'note': 'Unexpected note'},
      {..._state(), 'publishedOnProfile': false},
    ]) {
      test(
        'unconfirmed publication triggers an authoritative reload without reporting success: $malformed',
        () async {
          final h = _Harness();
          h.api.reply = malformed;
          final result = await h.repository.publish(
            postId: 'source',
            note: 'My note',
            expectedSession: h.session,
          );
          expect(result.isSuccess, isFalse);
          expect(h.repository.changes.value, 1);
        },
      );
    }

    test(
      'Unicode note limit uses code points and invalid commands do not reach the API',
      () async {
        final h = _Harness();
        final accepted = List.filled(500, '🎵').join();
        h.api.reply = {..._state(), 'note': accepted};
        expect(
          (await h.repository.publish(
            postId: 'source',
            note: accepted,
            expectedSession: h.session,
          )).isSuccess,
          isTrue,
        );
        for (final note in [
          '$accepted🎵',
          'before\u0001after',
          'before\u0085after',
          'before\rafter',
        ]) {
          expect(
            (await h.repository.publish(
              postId: 'source',
              note: note,
              expectedSession: h.session,
            )).isSuccess,
            isFalse,
          );
        }
        expect(
          (await h.repository.publish(
            postId: '../other',
            expectedSession: h.session,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await h.repository.listProfile(
            profileId: 'profile',
            page: 1001,
            expectedSession: h.session,
          )).isSuccess,
          isFalse,
        );
        expect(h.api.requests, hasLength(1));
        expect(h.repository.changes.value, 1);
      },
    );

    test('duplicate shares and wrong page responses fail closed', () async {
      final h = _Harness();
      final valid = _page();
      h.api.reply = {
        ...valid,
        'content': [valid['content'][0], valid['content'][0]],
      };
      expect(
        (await h.repository.listProfile(
          profileId: 'profile',
          page: 2,
          expectedSession: h.session,
        )).isSuccess,
        isFalse,
      );
      h.api.reply = valid;
      expect(
        (await h.repository.listProfile(
          profileId: 'profile',
          page: 1,
          expectedSession: h.session,
        )).isSuccess,
        isFalse,
      );
    });
  });

  group('session boundaries', () {
    test(
      'a musician can read public shares but cannot publish or inspect listener publication state',
      () async {
        final h = _Harness(session: audienceSession(role: 'ROLE_MUSICIAN'));
        h.api.reply = _page();
        expect(
          (await h.repository.listProfile(
            profileId: 'profile',
            page: 2,
            expectedSession: h.session,
          )).isSuccess,
          isTrue,
        );
        expect(
          (await h.repository.getState(
            postId: 'source',
            expectedSession: h.session,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await h.repository.publish(
            postId: 'source',
            expectedSession: h.session,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await h.repository.deleteShare(
            shareId: 'share',
            expectedSession: h.session,
          )).isSuccess,
          isFalse,
        );
        expect(h.api.requests, hasLength(1));
      },
    );

    test('guest has no public read or write dispatch', () async {
      final h = _Harness(session: const AuthSession.guest());
      expect(
        (await h.repository.listProfile(
          profileId: 'profile',
          expectedSession: h.session,
        )).isSuccess,
        isFalse,
      );
      expect(
        (await h.repository.publish(
          postId: 'source',
          expectedSession: h.session,
        )).isSuccess,
        isFalse,
      );
      expect(h.api.requests, isEmpty);
    });

    for (final action in ['state', 'publish', 'delete', 'list']) {
      test(
        'late $action response is discarded after same-user relogin',
        () async {
          final h = _Harness();
          final pending = Completer<Object?>();
          h.api.pending = pending;
          final operation = _call(h.repository, action, h.session);
          h.sessions.replace(audienceSession(token: 'new'));
          pending.complete(_payload(action));
          expect(
            (await operation).error?.code,
            'overthinking_profile_share_session_changed',
          );
          expect(h.repository.changes.value, 0);
        },
      );
    }

    test(
      'captured stale session cannot dispatch with the replacement account token',
      () async {
        final h = _Harness();
        final old = h.session;
        h.sessions.replace(audienceSession(user: 'other', token: 'new'));
        expect(
          (await h.repository.publish(
            postId: 'source',
            expectedSession: old,
          )).isSuccess,
          isFalse,
        );
        expect(h.api.requests, isEmpty);
      },
    );

    test(
      'session epoch rejects a pending response even if the same session object returns',
      () async {
        final h = _Harness();
        final expected = h.session;
        final pending = Completer<Object?>();
        h.api.pending = pending;
        final operation = h.repository.publish(
          postId: 'source',
          note: 'My note',
          expectedSession: expected,
        );
        h.sessions.replace(const AuthSession.guest());
        h.sessions.replace(expected);
        pending.complete(_state());
        expect((await operation).isSuccess, isFalse);
        expect(h.repository.changes.value, 0);
      },
    );

    test(
      'disposing with a pending publish never notifies a disposed signal',
      () async {
        final h = _Harness();
        final pending = Completer<Object?>();
        h.api.pending = pending;
        final operation = h.repository.publish(
          postId: 'source',
          note: 'My note',
          expectedSession: h.session,
        );
        h.repository.dispose();
        pending.complete(_state());
        expect((await operation).isSuccess, isFalse);
      },
    );
  });

  for (final action in ['state', 'publish', 'delete', 'list']) {
    for (final relogin in [false, true]) {
      test(
        'real Dio $action ${relogin ? 'rejects relogin' : 'dispatches unchanged session'} after token await',
        () async {
          final token = _jwt('old');
          final expected = audienceSession(token: token);
          final sessions = AudienceTestSessions(expected);
          final tokens = _BlockedTokens();
          final adapter = _Adapter(_payload(action));
          final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
            ..httpClientAdapter = adapter;
          final repository = OverthinkingProfileShareRepositoryImpl(
            DioApiClient(
              dio: dio,
              tokenStore: tokens,
              sessionManager: sessions,
            ),
            sessions: sessions,
          );
          addTearDown(() {
            repository.dispose();
            dio.close(force: true);
            sessions.dispose();
          });
          final operation = _call(repository, action, expected);
          await tokens.started.future;
          final nextToken = relogin ? _jwt('new') : token;
          if (relogin) sessions.replace(audienceSession(token: nextToken));
          tokens.release.complete(nextToken);
          final result = await operation;
          if (relogin) {
            expect(
              result.error?.code,
              'overthinking_profile_share_session_changed',
            );
            expect(adapter.requests, isEmpty);
            expect(repository.changes.value, 0);
          } else {
            expect(result.isSuccess, isTrue, reason: result.error?.message);
            expect(adapter.requests, hasLength(1));
            expect(
              adapter.requests.single.headers['Authorization'],
              'Bearer $token',
            );
            expect(
              repository.changes.value,
              ['publish', 'delete'].contains(action) ? 1 : 0,
            );
          }
        },
      );
    }
  }
}

Future<Result<dynamic>> _call(
  OverthinkingProfileShareRepository repository,
  String action,
  AuthSession session,
) => switch (action) {
  'state' => repository.getState(postId: 'source', expectedSession: session),
  'publish' => repository.publish(
    postId: 'source',
    note: 'My note',
    expectedSession: session,
  ),
  'delete' => repository.deleteShare(
    shareId: 'share',
    expectedSession: session,
  ),
  'list' => repository.listProfile(
    profileId: 'profile',
    page: 2,
    expectedSession: session,
  ),
  _ => throw StateError(action),
};

Object? _payload(String action) => switch (action) {
  'list' => _page(),
  'delete' => null,
  _ => _state(),
};

Map<String, dynamic> _state({bool published = true, bool canPublish = true}) =>
    {
      'postId': 'source',
      'shareId': published ? 'share' : null,
      'publishedOnProfile': published,
      'note': published ? 'My note' : null,
      'publishedAt': published ? '2026-09-10T12:00:00Z' : null,
      'canPublish': canPublish,
    };

Map<String, dynamic> _page() => {
  'number': 2,
  'last': false,
  'content': [
    {
      'shareId': 'share',
      'note': 'My note',
      'publishedAt': '2026-09-10T12:00:00Z',
      'post': {
        'id': 'source',
        'anonymous': true,
        'canViewAuthor': false,
        'authorId': null,
        'authorUsername': 'Anonim',
        'title': 'Thought',
        'revealRequestPending': true,
        'spotifyTrackName': 'Song',
      },
    },
  ],
};

class _Request {
  _Request(this.method, this.path, this.body, this.query, this.context);
  final ApiHttpMethod method;
  final String path;
  final Object? body;
  final Map<String, dynamic>? query;
  final ApiRequestContext? context;
}

class _Api extends Fake implements ApiClient {
  final requests = <_Request>[];
  Object? reply;
  AppError? error;
  Completer<Object?>? pending;
  FutureOr<Object?> Function(_Request)? handler;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    requests.add(_Request(method, path, body, query, requestContext));
    if (error != null) throw ApiException(error!);
    final raw = handler != null
        ? await handler!(requests.last)
        : pending == null
        ? reply
        : await pending!.future;
    return decoder == null ? raw as T : decoder(raw);
  }
}

class _Harness {
  _Harness({AuthSession? session}) {
    sessions = AudienceTestSessions(session ?? audienceSession());
    repository = OverthinkingProfileShareRepositoryImpl(
      api,
      sessions: sessions,
    );
    addTearDown(() {
      repository.dispose();
      sessions.dispose();
    });
  }
  final api = _Api();
  late final AudienceTestSessions sessions;
  late final OverthinkingProfileShareRepositoryImpl repository;
  AuthSession get session => sessions.session;
}

String _jwt(String nonce) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': 'listener', 'jti': nonce, 'exp': 4102444800})}.signature';
}

class _BlockedTokens extends Fake implements TokenStore {
  final started = Completer<void>();
  final release = Completer<String?>();
  @override
  Future<String?> readToken() {
    if (!started.isCompleted) started.complete();
    return release.future;
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.payload);
  final Object? payload;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'code': 200, 'data': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
