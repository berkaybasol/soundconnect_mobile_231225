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

void main() {
  for (final target in ['OVERTHINKING', 'OVERTHINKING_PROFILE_SHARE']) {
    for (final liked in [true, false]) {
      final action = liked ? 'like' : 'unlike';
      for (final replaceSession in [true, false]) {
        test(
          '$target $action ${replaceSession ? 'cannot adopt a same-account relogin token' : 'dispatches for the unchanged session'} after token await',
          () async {
            final oldToken = _jwt('old');
            final newToken = _jwt('new');
            final sessions = AudienceTestSessions(
              audienceSession(user: 'author', token: oldToken),
            );
            final tokens = _BlockedTokens();
            final adapter = _RecordingAdapter();
            final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
              ..httpClientAdapter = adapter;
            addTearDown(() {
              dio.close(force: true);
              sessions.dispose();
            });
            final repository = EngagementRepositoryImpl(
              DioApiClient(
                dio: dio,
                tokenStore: tokens,
                sessionManager: sessions,
              ),
              sessions: sessions,
            );

            final pending = liked
                ? repository.like(targetType: target, targetId: 'post')
                : repository.unlike(targetType: target, targetId: 'post');
            await tokens.started.future;
            if (replaceSession) {
              sessions.replace(const AuthSession.guest());
              sessions.replace(
                audienceSession(user: 'author', token: newToken),
              );
            }
            tokens.release.complete(replaceSession ? newToken : oldToken);
            final result = await pending;

            if (replaceSession) {
              expect(result.error?.code, 'engagement_comment_session_changed');
              // Dropping only the response is too late: the server must never
              // receive a mutation authenticated with the replacement token.
              expect(adapter.requests, isEmpty);
            } else {
              expect(result.isSuccess, isTrue);
              expect(adapter.requests, hasLength(1));
              expect(adapter.requests.single.method, liked ? 'POST' : 'DELETE');
              expect(
                adapter.requests.single.path,
                '/api/v1/likes/$target/post',
              );
              expect(
                adapter.requests.single.headers['Authorization'],
                'Bearer $oldToken',
              );
            }
          },
        );
      }
    }
  }
}

String _jwt(String nonce) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': 'author', 'jti': nonce, 'exp': 4102444800})}.signature';
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

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'code': 200, 'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
