import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';

void main() {
  group('DioApiClient transport contract', () {
    test(
      'authenticates private requests but leaves public requests clean',
      () async {
        final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
          (RequestOptions options) => _jsonResponse(
            statusCode: 200,
            payload: <String, dynamic>{
              'success': true,
              'code': 200,
              'data': <String, dynamic>{
                'value': options.path.contains('private') ? '7' : '8',
              },
            },
          ),
        );
        final Dio dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final _MemoryTokenStore tokenStore = _MemoryTokenStore('access-token');
        final DioApiClient client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
        );

        final int privateValue = await client.get<int>(
          '/api/v1/private/value',
          decoder: _decodeValue,
        );
        final int publicValue = await client.get<int>(
          '/api/v1/events/discover',
          decoder: _decodeValue,
        );

        expect(privateValue, 7);
        expect(publicValue, 8);
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.first.headers['Authorization'],
          'Bearer access-token',
        );
        expect(
          adapter.requests.last.headers.containsKey('Authorization'),
          isFalse,
        );
        expect(tokenStore.readCount, 1);
      },
    );

    test(
      'decodes a successful envelope through the supplied decoder',
      () async {
        final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 200,
            payload: <String, dynamic>{
              'success': true,
              'message': 'ok',
              'code': 200,
              'data': <String, dynamic>{'value': '42'},
            },
          ),
        );
        final Dio dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final DioApiClient client = DioApiClient(
          dio: dio,
          tokenStore: _MemoryTokenStore(null),
        );

        final int value = await client.get<int>(
          '/api/v1/events/value',
          decoder: _decodeValue,
        );

        expect(value, 42);
        expect(adapter.requests.single.method, 'GET');
        expect(adapter.requests.single.path, '/api/v1/events/value');
      },
    );

    test('unwraps scalar and null auth response data', () async {
      final adapter = _RecordingHttpClientAdapter(
        (options) => _jsonResponse(
          statusCode: 200,
          payload: <String, dynamic>{
            'success': true,
            'message': 'ok',
            'code': 200,
            'data': options.path == '/api/v1/users/me/username'
                ? 'new-name'
                : null,
          },
        ),
      );
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final client = DioApiClient(
        dio: dio,
        tokenStore: _MemoryTokenStore(null),
      );

      final username = await client.request<String>(
        ApiHttpMethod.patch,
        '/api/v1/users/me/username',
        body: const <String, String>{'username': 'new-name'},
        decoder: (json) => json?.toString() ?? '',
      );
      final resetRequest = await client.request<Object?>(
        ApiHttpMethod.post,
        '/api/v1/auth/forgot-password',
        body: const <String, String>{'email': 'user@example.com'},
        decoder: (_) => null,
      );

      expect(username, 'new-name');
      expect(resetRequest, isNull);
      expect(adapter.requests.map((request) => request.method), <String>[
        'PATCH',
        'POST',
      ]);
    });

    test('maps a rejected success-status envelope to ApiException', () async {
      final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 200,
          payload: <String, dynamic>{
            'success': false,
            'message': 'Conflict',
            'code': 409,
            'data': null,
          },
        ),
      );
      final Dio dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final DioApiClient client = DioApiClient(
        dio: dio,
        tokenStore: _MemoryTokenStore(null),
      );

      await expectLater(
        client.get<Object?>('/api/v1/events/conflict'),
        throwsA(
          isA<ApiException>()
              .having((ApiException error) => error.error.code, 'code', '409')
              .having(
                (ApiException error) => error.error.message,
                'message',
                'Conflict',
              ),
        ),
      );
    });

    test(
      'maps HTTP error details, code, and message deterministically',
      () async {
        final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 422,
            payload: <String, dynamic>{
              'code': 9251,
              'message': 'Invalid parameter',
              'details': <String>['Neighborhood is invalid', 'Second detail'],
            },
          ),
        );
        final Dio dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final DioApiClient client = DioApiClient(
          dio: dio,
          tokenStore: _MemoryTokenStore(null),
        );

        await expectLater(
          client.get<Object?>('/api/v1/events/invalid'),
          throwsA(
            isA<ApiException>()
                .having(
                  (ApiException error) => error.error.code,
                  'code',
                  '9251',
                )
                .having(
                  (ApiException error) => error.error.message,
                  'message',
                  'Neighborhood is invalid',
                )
                .having(
                  (ApiException error) => error.error.details,
                  'details',
                  <String>['Neighborhood is invalid', 'Second detail'],
                ),
          ),
        );
      },
    );

    test(
      'preserves a string Collab conflict code from an HTTP error',
      () async {
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 409,
            payload: <String, dynamic>{
              'code': '9317',
              'message': 'Kayıt değişti; yenileyip tekrar deneyin.',
            },
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: _MemoryTokenStore(null),
        );

        await expectLater(
          client.get<Object?>('/api/v1/collabs/listing-1'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.error.code,
              'code',
              '9317',
            ),
          ),
        );
      },
    );

    test('401 rejects only the token attached to a private request', () async {
      final String token = _jwt(
        subject: 'user-1',
        roles: const <String>['ROLE_LISTENER'],
      );
      final _MemoryTokenStore tokenStore = _MemoryTokenStore(token);
      final _MemorySessionStore sessionStore = _MemorySessionStore(
        const AuthSessionMetadata(accountStatus: 'ACTIVE'),
      );
      var sessionEndedCount = 0;
      final AuthSessionManager sessionManager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
        onSessionEnded: () async => sessionEndedCount += 1,
      );
      addTearDown(sessionManager.dispose);
      await sessionManager.restore();
      final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 401,
          payload: <String, dynamic>{
            'code': 401,
            'message': 'Unauthorized',
            'details': <String>[],
          },
        ),
      );
      final Dio dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final DioApiClient client = DioApiClient(
        dio: dio,
        tokenStore: tokenStore,
        sessionManager: sessionManager,
      );

      await expectLater(
        client.get<Object?>('/api/v1/events/discover'),
        throwsA(isA<ApiException>()),
      );
      expect(sessionManager.session.isAuthenticated, isTrue);
      expect(sessionEndedCount, 0);

      await expectLater(
        client.get<Object?>('/api/v1/private/profile'),
        throwsA(isA<ApiException>()),
      );

      expect(sessionManager.session.isAuthenticated, isFalse);
      expect(sessionEndedCount, 1);
      expect(tokenStore.value, isNull);
      expect(sessionStore.value, isNull);
      expect(
        adapter.requests.first.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(adapter.requests.last.headers['Authorization'], 'Bearer $token');
    });

    test(
      'session fence rejects A recovery after token read crosses into B',
      () async {
        final tokenA = _jwt(
          subject: 'account-A',
          roles: const <String>['ROLE_LISTENER'],
        );
        final tokenB = _jwt(
          subject: 'account-B',
          roles: const <String>['ROLE_LISTENER'],
        );
        final tokenStore = _BarrierTokenStore(tokenA);
        final sessionStore = _MemorySessionStore(
          const AuthSessionMetadata(accountStatus: 'ACTIVE'),
        );
        final sessionManager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: sessionStore,
        );
        addTearDown(sessionManager.dispose);
        await sessionManager.restore();

        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 200,
            payload: <String, dynamic>{
              'success': true,
              'code': 200,
              'data': null,
            },
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessionManager,
        );

        tokenStore.armBarrier();
        final request = client.request<Object?>(
          ApiHttpMethod.post,
          '/api/v1/user/media/complete-upload',
          body: const <String, String>{'assetId': 'asset-A'},
          requestContext: const ApiRequestContext(
            expectedSessionKey: 'account-A',
          ),
        );
        await tokenStore.readStarted.future.timeout(const Duration(seconds: 2));

        await sessionManager.startSession(
          token: tokenB,
          username: 'account-B',
          accountStatus: 'ACTIVE',
        );
        final fenced = expectLater(
          request,
          throwsA(
            isA<ApiException>().having(
              (error) => error.error.code,
              'code',
              'api_session_fence',
            ),
          ),
        );
        tokenStore.releaseRead();

        await fenced;
        expect(sessionManager.session.userId, 'account-B');
        expect(adapter.requests, isEmpty);
      },
    );
  });
}

int _decodeValue(Object? json) {
  final Map<String, dynamic> value = json! as Map<String, dynamic>;
  return int.parse(value['value']! as String);
}

Dio _dio(HttpClientAdapter adapter) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test',
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

void _closeDio(Dio dio, _RecordingHttpClientAdapter adapter) {
  dio.close(force: true);
  expect(adapter.closed, isTrue);
}

ResponseBody _jsonResponse({required int statusCode, required Object payload}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
    },
  );
}

typedef _ResponseFactory = ResponseBody Function(RequestOptions options);

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter(this._responseFactory);

  final _ResponseFactory _responseFactory;
  final List<_RequestRecord> requests = <_RequestRecord>[];
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _RequestRecord(
        method: options.method,
        path: options.path,
        headers: Map<String, dynamic>.from(options.headers),
      ),
    );
    return _responseFactory(options);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

class _RequestRecord {
  const _RequestRecord({
    required this.method,
    required this.path,
    required this.headers,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.value);

  String? value;
  int readCount = 0;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async {
    readCount += 1;
    return value;
  }

  @override
  Future<void> writeToken(String token) async => value = token;
}

class _BarrierTokenStore extends _MemoryTokenStore {
  _BarrierTokenStore(super.value);

  final Completer<void> readStarted = Completer<void>();
  Completer<void>? _release;

  void armBarrier() => _release = Completer<void>();

  void releaseRead() => _release?.complete();

  @override
  Future<String?> readToken() async {
    final release = _release;
    if (release != null) {
      if (!readStarted.isCompleted) readStarted.complete();
      await release.future;
      _release = null;
    }
    return super.readToken();
  }
}

class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.value);

  AuthSessionMetadata? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthSessionMetadata?> read() async => value;

  @override
  Future<void> write(AuthSessionMetadata metadata) async => value = metadata;
}

String _jwt({required String subject, required List<String> roles}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final int expiresAt =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;

  return '${encode(<String, String>{'alg': 'HS256'})}.'
      '${encode(<String, Object>{'sub': subject, 'exp': expiresAt, 'roles': roles})}.'
      'signature';
}
