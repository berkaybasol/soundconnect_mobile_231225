import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';

import 'support/event_audience_fakes.dart';

const _shareId = 'publication-id';
const _target = 'TABLE_GROUP_POST';

void main() {
  test(
    'real Dio sends table publication likes and comments with viewer identity',
    () async {
      final h = _Harness();
      final repository = h.repository;
      expect(
        (await repository.getLikeCount(
          targetType: _target,
          targetId: _shareId,
        )).data,
        2,
      );
      expect(
        (await repository.isLiked(
          targetType: _target,
          targetId: _shareId,
        )).data,
        isTrue,
      );
      expect(
        (await repository.like(
          targetType: _target,
          targetId: _shareId,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.unlike(
          targetType: _target,
          targetId: _shareId,
        )).isSuccess,
        isTrue,
      );
      final comments = await repository.listComments(
        targetType: _target,
        targetId: _shareId,
      );
      expect(comments.isSuccess, isTrue);
      expect(comments.data!.items.single.id, 'comment-id');
      expect(comments.data!.items.single.likedByMe, isTrue);
      expect(
        (await repository.createComment(
          targetType: _target,
          targetId: _shareId,
          text: '  Buluşalım 🎵  ',
        )).data?.text,
        'Buluşalım 🎵',
      );
      expect(
        h.adapter.requests.map((request) => (request.method, request.path)),
        [
          ('GET', '/api/v1/likes/TABLE_GROUP_POST/$_shareId/count'),
          ('GET', '/api/v1/likes/TABLE_GROUP_POST/$_shareId/is-liked'),
          ('POST', '/api/v1/likes/TABLE_GROUP_POST/$_shareId'),
          ('DELETE', '/api/v1/likes/TABLE_GROUP_POST/$_shareId'),
          ('GET', '/api/v1/comments/TABLE_GROUP_POST/$_shareId'),
          ('POST', '/api/v1/comments/TABLE_GROUP_POST/$_shareId'),
        ],
      );
      expect(
        h.adapter.requests.map((request) => request.headers['Authorization']),
        everyElement('Bearer ${h.token}'),
      );
      expect(h.adapter.requests.last.data, {
        'text': 'Buluşalım 🎵',
        'parentCommentId': null,
      });
      expect(h.adapter.requests[4].queryParameters, {
        'page': 0,
        'size': 20,
        'sort': 'createdAt,desc',
      });
    },
  );

  test(
    'guest table publication requests cannot use anonymous event routes',
    () async {
      final h = _Harness(guest: true);
      expect(
        (await h.repository.listComments(
          targetType: _target,
          targetId: _shareId,
        )).isSuccess,
        isFalse,
      );
      expect(
        (await h.repository.like(
          targetType: _target,
          targetId: _shareId,
        )).isSuccess,
        isFalse,
      );
      expect(h.adapter.requests, isEmpty);
    },
  );

  for (final comments in [false, true]) {
    test(
      'same-user relogin fences table ${comments ? 'comments' : 'likes'} before dispatch',
      () async {
        final h = _Harness();
        final started = Completer<void>();
        final release = Completer<String?>();
        h.tokens.onRead = () {
          started.complete();
          return release.future;
        };
        final request = comments
            ? h.repository.listComments(targetType: _target, targetId: _shareId)
            : h.repository.like(targetType: _target, targetId: _shareId);
        await started.future;
        final replacement = _jwt('replacement');
        h.sessions.replace(audienceSession(token: replacement));
        release.complete(replacement);
        final result = await request;
        expect(result.isSuccess, isFalse);
        expect(h.adapter.requests, isEmpty);
      },
    );
  }

  test(
    'inaccessible table publication never falls back to table chat or event comments',
    () async {
      final h = _Harness();
      h.adapter.status = 403;
      final result = await h.repository.listComments(
        targetType: _target,
        targetId: _shareId,
      );
      expect(result.isSuccess, isFalse);
      expect(h.adapter.requests, hasLength(1));
      expect(
        h.adapter.requests.single.path,
        '/api/v1/comments/TABLE_GROUP_POST/$_shareId',
      );
    },
  );
}

class _Harness {
  _Harness({bool guest = false}) {
    sessions = AudienceTestSessions(
      guest ? const AuthSession.guest() : audienceSession(token: token),
    );
    tokens = _Tokens(token);
    dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
      ..httpClientAdapter = adapter;
    repository = EngagementRepositoryImpl(
      DioApiClient(dio: dio, tokenStore: tokens, sessionManager: sessions),
      sessions: sessions,
    );
    addTearDown(() {
      dio.close(force: true);
      sessions.dispose();
    });
  }

  final token = _jwt('original');
  final adapter = _Adapter();
  late final AudienceTestSessions sessions;
  late final _Tokens tokens;
  late final Dio dio;
  late final EngagementRepositoryImpl repository;
}

class _Tokens extends Fake implements TokenStore {
  _Tokens(this.token);
  final String token;
  Future<String?> Function()? onRead;
  @override
  Future<String?> readToken() => onRead?.call() ?? Future.value(token);
}

String _jwt(String nonce) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': 'listener', 'jti': nonce, 'exp': 4102444800})}.signature';
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object? data;
    if (options.path.endsWith('/count')) {
      data = 2;
    } else if (options.path.endsWith('/is-liked')) {
      data = true;
    } else if (options.path.startsWith('/api/v1/comments/')) {
      final comment = {
        'id': 'comment-id',
        'text': 'Buluşalım 🎵',
        'parentCommentId': null,
        'deleted': false,
        'anonymousAuthor': false,
        'replyCount': 0,
        'likeCount': 2,
        'likedByMe': true,
        'user': {'id': 'listener', 'username': 'berna'},
      };
      data = options.method == 'POST'
          ? comment
          : {
              'content': [comment],
              'totalElements': 1,
              'number': 0,
              'size': 20,
              'totalPages': 1,
              'first': true,
              'last': true,
            };
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': status == 200,
        'code': status,
        'data': data,
        'message': 'Unavailable',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
