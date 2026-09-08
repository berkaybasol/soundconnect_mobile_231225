import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_like_button.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/brand_gradient_icon.dart';

const _actor = 'e0000000-0000-4000-8000-000000000001';
const _event = 'e0000000-0000-4000-8000-000000000002';
const _root = 'e0000000-0000-4000-8000-000000000003';
const _reply = 'e0000000-0000-4000-8000-000000000004';
const _secondActor = 'e0000000-0000-4000-8000-000000000005';

void main() {
  for (final replies in [false, true]) {
    final label = replies ? 'reply' : 'root';
    final commentId = replies ? _reply : _root;

    test(
      '$label initial signed-in page restores persisted personal like',
      () async {
        final harness = await _Harness.create(signedIn: true);
        addTearDown(harness.dispose);
        harness.adapter.likes[commentId]!.add(_actor);

        final comment = await _read(harness.repository(), replies: replies);

        expect(comment.likeCount, 3);
        expect(comment.likedByMe, isTrue);
        expect(harness.adapter.requests, hasLength(1));
        final request = harness.adapter.requests.single;
        expect(request.path, _privatePage(replies));
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer ${harness.token}');
      },
    );

    test(
      '$label write and repeated reopen retain the server like projection',
      () async {
        final harness = await _Harness.create(signedIn: true);
        addTearDown(harness.dispose);
        var repository = harness.repository();
        final initial = await _read(repository, replies: replies);
        expect((initial.likeCount, initial.likedByMe), (2, false));

        final written = await repository.setCommentLike(
          commentId: commentId,
          liked: true,
        );
        expect(written.isSuccess, isTrue, reason: '${written.error}');
        expect((written.data!.likeCount, written.data!.likedByMe), (3, true));

        // A new repository represents a fresh screen load without any widget or
        // parent-scoped optimistic cache surviving. Only transport data can win.
        for (var reopen = 0; reopen < 2; reopen++) {
          repository = harness.repository();
          final restored = await _read(repository, replies: replies);
          expect(restored.likeCount, 3);
          expect(restored.likedByMe, isTrue);
        }

        final removed = await repository.setCommentLike(
          commentId: commentId,
          liked: false,
        );
        expect(removed.isSuccess, isTrue, reason: '${removed.error}');
        final restored = await _read(harness.repository(), replies: replies);
        expect((restored.likeCount, restored.likedByMe), (2, false));
        expect(harness.adapter.requests.map((request) => request.method), [
          'GET',
          'POST',
          'GET',
          'GET',
          'DELETE',
          'GET',
        ]);
        final reads = harness.adapter.requests.where(
          (request) => request.method == 'GET',
        );
        expect(
          reads.map((request) => request.path),
          everyElement(_privatePage(replies)),
        );
        expect(
          harness.adapter.requests.map(
            (request) => request.headers['Authorization'],
          ),
          everyElement('Bearer ${harness.token}'),
        );
        expect(
          harness.adapter.requests.where(
            (request) => request.path.endsWith('/state'),
          ),
          isEmpty,
        );
      },
    );
  }

  testWidgets(
    'transport projections mount selected root and reply hearts after full remount',
    (tester) async {
      final harness = (await tester.runAsync(
        () => _Harness.create(signedIn: true),
      ))!;
      addTearDown(harness.dispose);
      harness.adapter.likes[_root]!.add(_actor);
      harness.adapter.likes[_reply]!.add(_actor);
      final semantics = tester.ensureSemantics();
      try {
        for (var reopen = 0; reopen < 2; reopen++) {
          final repository = harness.repository();
          final comments = (await tester.runAsync(
            () => Future.wait([
              _read(repository, replies: false),
              _read(repository, replies: true),
            ]),
          ))!;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.navy,
              home: Scaffold(
                body: Column(
                  children: [
                    for (final comment in comments)
                      CommentLikeButton(
                        comment: comment,
                        compact: comment.id == _reply,
                        repository: repository,
                        sessions: harness.sessions,
                        isCurrent: () => true,
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.byTooltip('Beğeniyi kaldır'), findsNWidgets(2));
          expect(
            find.bySemanticsLabel('Beğeniyi kaldır, 3 beğeni'),
            findsNWidgets(2),
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Beğeniyi kaldır, 3 beğeni' &&
                  widget.properties.toggled == true,
            ),
            findsNWidgets(2),
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is BrandGradientIcon &&
                  widget.icon == Icons.favorite_rounded,
            ),
            findsNWidgets(2),
          );
          expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
          expect(harness.adapter.requests, hasLength((reopen + 1) * 2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
        expect(harness.adapter.requests.map((request) => request.path), [
          _privatePage(false),
          _privatePage(true),
          _privatePage(false),
          _privatePage(true),
        ]);
        expect(
          harness.adapter.requests.map((request) => request.method),
          everyElement('GET'),
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  test(
    'guest root and reply pages keep the same totals but no personal projection or JWT',
    () async {
      final harness = await _Harness.create(signedIn: false);
      addTearDown(harness.dispose);
      harness.adapter.likes[_root]!.add(_actor);
      harness.adapter.likes[_reply]!.add(_actor);

      for (final replies in [false, true]) {
        final comment = await _read(harness.repository(), replies: replies);
        expect((comment.likeCount, comment.likedByMe), (3, false));
      }
      expect(harness.adapter.requests.map((request) => request.path), [
        '/api/v1/events/$_event/comments',
        '/api/v1/events/$_event/comments/$_root/replies',
      ]);
      expect(harness.adapter.requests.map((request) => request.method), [
        'GET',
        'GET',
      ]);
      for (final request in harness.adapter.requests) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
    },
  );

  test(
    'account switch recomputes root and reply hearts for the new viewer',
    () async {
      final harness = await _Harness.create(signedIn: true);
      addTearDown(harness.dispose);
      for (final id in [_root, _reply]) {
        harness.adapter.likes[id]!.add(_actor);
      }
      final repository = harness.repository();
      for (final replies in [false, true]) {
        final own = await _read(repository, replies: replies);
        expect((own.likeCount, own.likedByMe), (3, true));
      }
      final secondToken = await harness.signIn(_secondActor);
      for (final replies in [false, true]) {
        final other = await _read(repository, replies: replies);
        expect((other.likeCount, other.likedByMe), (3, false));
      }
      expect(harness.adapter.requests, hasLength(4));
      expect(
        harness.adapter.requests
            .skip(2)
            .map((request) => request.headers['Authorization']),
        everyElement('Bearer $secondToken'),
      );
    },
  );

  for (final replies in [false, true]) {
    final label = replies ? 'reply' : 'root';
    test(
      '$label late response after account change is discarded without retry',
      () async {
        final harness = await _Harness.create(signedIn: true);
        addTearDown(harness.dispose);
        final started = Completer<void>();
        final release = Completer<void>();
        harness.adapter.beforePageResponse = () async {
          started.complete();
          await release.future;
        };
        final repository = harness.repository();
        final pending = replies
            ? repository.listReplyPage(_root, eventId: _event)
            : repository.listComments(targetType: 'EVENT', targetId: _event);
        await started.future;
        await harness.signIn(_secondActor);
        release.complete();
        final result = await pending;
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error!.code, 'engagement_comment_session_changed');
        expect(harness.adapter.requests, hasLength(1));
        expect(harness.adapter.requests.single.path, _privatePage(replies));
      },
    );

    test(
      '$label token-store account drift is blocked before HTTP dispatch',
      () async {
        final harness = await _Harness.create(signedIn: true);
        addTearDown(harness.dispose);
        await harness.tokens.writeToken(_jwt(subject: _secondActor));
        final repository = harness.repository();
        final result = replies
            ? await repository.listReplyPage(_root, eventId: _event)
            : await repository.listComments(
                targetType: 'EVENT',
                targetId: _event,
              );
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(harness.adapter.requests, isEmpty);
        expect(harness.sessions.session.userId, _actor);
      },
    );

    test(
      '$label authoritative 401 ends the session without a guest-state fallback',
      () async {
        final harness = await _Harness.create(signedIn: true);
        addTearDown(harness.dispose);
        harness.adapter.rejectPrivatePages = true;
        final repository = harness.repository();
        final result = replies
            ? await repository.listReplyPage(_root, eventId: _event)
            : await repository.listComments(
                targetType: 'EVENT',
                targetId: _event,
              );
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(
          result.error!.code,
          anyOf('401', 'engagement_comment_session_changed'),
        );
        expect(harness.sessions.session.isAuthenticated, isFalse);
        expect(harness.adapter.requests, hasLength(1));
        expect(harness.adapter.requests.single.path, _privatePage(replies));
        expect(
          harness.adapter.requests.single.headers['Authorization'],
          'Bearer ${harness.token}',
        );
      },
    );
  }
}

String _privatePage(bool replies) => replies
    ? '/api/v1/comments/replies/$_root'
    : '/api/v1/comments/EVENT/$_event';

Future<CommentItem> _read(
  EngagementRepositoryImpl repository, {
  required bool replies,
}) async {
  final result = replies
      ? await repository.listReplyPage(_root, eventId: _event)
      : await repository.listComments(targetType: 'EVENT', targetId: _event);
  expect(result.isSuccess, isTrue, reason: '${result.error}');
  expect(result.data!.items, hasLength(1));
  return result.data!.items.single;
}

class _Harness {
  _Harness(
    this.token,
    this.tokens,
    this.sessions,
    this.adapter,
    this.dio,
    this.client,
  );

  final String token;
  final _MemoryTokenStore tokens;
  final AuthSessionManager sessions;
  final _BearerAwareAdapter adapter;
  final Dio dio;
  final DioApiClient client;

  static Future<_Harness> create({required bool signedIn}) async {
    final token = _jwt();
    final tokens = _MemoryTokenStore();
    final sessions = AuthSessionManager(
      tokenStore: tokens,
      sessionStore: _MemorySessionStore(),
    );
    if (signedIn) {
      await sessions.startSession(
        token: token,
        username: 'listener',
        accountStatus: 'ACTIVE',
      );
      expect(sessions.session.userId, _actor);
      expect(sessions.session.requiresListenerProfileChoice, isFalse);
    }
    final adapter = _BearerAwareAdapter(token);
    final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
      ..httpClientAdapter = adapter;
    final client = DioApiClient(
      dio: dio,
      tokenStore: tokens,
      sessionManager: sessions,
    );
    return _Harness(token, tokens, sessions, adapter, dio, client);
  }

  Future<String> signIn(String actor) async {
    final nextToken = _jwt(subject: actor);
    adapter.viewersByAuthorization['Bearer $nextToken'] = actor;
    await sessions.startSession(
      token: nextToken,
      username: 'listener',
      accountStatus: 'ACTIVE',
    );
    return nextToken;
  }

  EngagementRepositoryImpl repository() =>
      EngagementRepositoryImpl(client, sessions: sessions);

  void dispose() {
    sessions.dispose();
    dio.close(force: true);
  }
}

class _BearerAwareAdapter implements HttpClientAdapter {
  _BearerAwareAdapter(String token)
    : viewersByAuthorization = {'Bearer $token': _actor};
  final Map<String, String> viewersByAuthorization;
  Future<void> Function()? beforePageResponse;
  bool rejectPrivatePages = false;
  final requests = <RequestOptions>[];
  final likes = <String, Set<String>>{
    _root: {'other-a', 'other-b'},
    _reply: {'other-a', 'other-b'},
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final viewer = viewersByAuthorization[options.headers['Authorization']];
    final path = options.path;
    if (path.startsWith('/api/v1/likes/COMMENT/')) {
      if (viewer == null) return _response(null, status: 401);
      final id = path.substring('/api/v1/likes/COMMENT/'.length);
      expect(
        likes.containsKey(id),
        isTrue,
        reason: 'No per-row state GET should be needed',
      );
      if (options.method == 'POST') {
        likes[id]!.add(viewer);
      } else {
        expect(options.method, 'DELETE');
        likes[id]!.remove(viewer);
      }
      return _response({
        'likeCount': likes[id]!.length,
        'likedByMe': likes[id]!.contains(viewer),
      });
    }
    expect(options.method, 'GET');
    final private = path == _privatePage(false) || path == _privatePage(true);
    if (private && (viewer == null || rejectPrivatePages)) {
      return _response(null, status: 401);
    }
    final replies = path == _privatePage(true) || path.endsWith('/replies');
    expect(
      path,
      private
          ? _privatePage(replies)
          : replies
          ? '/api/v1/events/$_event/comments/$_root/replies'
          : '/api/v1/events/$_event/comments',
    );
    final id = replies ? _reply : _root;
    await beforePageResponse?.call();
    return _response({
      'content': [
        {
          'id': id,
          'text': replies ? 'Yanıt' : 'Yorum',
          'user': {'id': _actor, 'username': 'listener'},
          'parentCommentId': replies ? _root : null,
          'replyCount': replies ? 0 : 1,
          'createdAt': '2026-09-09T12:00:00Z',
          'deleted': false,
          'anonymousAuthor': false,
          'likeCount': likes[id]!.length,
          'likedByMe': viewer != null && likes[id]!.contains(viewer),
        },
      ],
      'number': 0,
      'size': 20,
      'totalElements': 1,
      'totalPages': 1,
      'first': true,
      'last': true,
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'success': status == 200, 'code': status, 'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );

class _MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<String?> readToken() async => value;
  @override
  Future<void> writeToken(String token) async => value = token;
}

class _MemorySessionStore implements AuthSessionStore {
  AuthSessionMetadata? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<AuthSessionMetadata?> read() async => value;
  @override
  Future<void> write(AuthSessionMetadata metadata) async => value = metadata;
}

String _jwt({String subject = _actor}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;
  return '${encode({'alg': 'HS256'})}.${encode({
    'sub': subject,
    'exp': expiry,
    'roles': ['ROLE_LISTENER'],
  })}.test-signature';
}
