import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/error/studio_rejection_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/auth_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/media_gallery_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_search_repository_impl.dart';

part 'dio_api_client_contract_test_register_dio_api_client_transport_contract1.dart';
part 'dio_api_client_contract_test_register_dio_api_client_transport_contract2.dart';
part 'dio_api_client_contract_test_register_dio_api_client_contract3.dart';

void main() {
  _registerDioApiClientContract3();
  for (final path in [
    '/api/v1/session/access',
    '/api/v1/auth/login',
    '/api/v1/auth/google-sign-in',
    '/api/v1/auth/complete-google-profile',
    '/api/v1/auth/verify-code',
    '/api/v1/auth/reset-password',
  ]) {
    final guest = path.startsWith('/api/v1/auth/');
    test('suspension from $path retires only the current credential', () async {
      final token = _jwt(subject: 'member-A', roles: ['ROLE_MUSICIAN']);
      final tokens = _MemoryTokenStore(guest ? null : token);
      final metadata = _MemorySessionStore(null);
      final manager = AuthSessionManager(
        tokenStore: tokens,
        sessionStore: metadata,
      );
      addTearDown(manager.dispose);
      await manager.restore();
      final adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 403,
          payload: {'code': 1119, 'message': 'Hesabınız askıya alındı.'},
        ),
      );
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final api = DioApiClient(
        dio: dio,
        tokenStore: tokens,
        sessionManager: manager,
      );
      final request = guest
          ? api.request<void>(
              ApiHttpMethod.post,
              path,
              requestContext: ApiRequestContext(
                requireGuestSession: true,
                expectedCredentialRevision: manager.credentialRevision,
              ),
            )
          : api.get<void>(path);
      await expectLater(request, throwsA(isA<ApiException>()));
      expect(manager.session.isSuspendedNotice, isTrue);
      expect(tokens.value, isNull);
      expect(metadata.value?.accountStatus, 'SUSPENDED');
      await manager.restore();
      expect(manager.session.isSuspendedNotice, isTrue);
      await manager.dismissSuspension();
      expect(manager.session.isSuspendedNotice, isFalse);
      expect(metadata.value, isNull);
    });
  }
  test(
    'late suspended bearer and generic 403 leave the new account open',
    () async {
      final tokens = _MemoryTokenStore(
        _jwt(subject: 'member-A', roles: ['ROLE_MUSICIAN']),
      );
      final manager = AuthSessionManager(
        tokenStore: tokens,
        sessionStore: _MemorySessionStore(null),
      );
      addTearDown(manager.dispose);
      await manager.restore();
      final started = Completer<void>();
      final reply = Completer<ResponseBody>();
      final adapter = _RecordingHttpClientAdapter((_) {
        if (started.isCompleted) {
          return _jsonResponse(statusCode: 403, payload: {'code': 1101});
        }
        started.complete();
        return reply.future;
      });
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final api = DioApiClient(
        dio: dio,
        tokenStore: tokens,
        sessionManager: manager,
      );
      final pending = expectLater(
        api.get<void>('/api/v1/session/access'),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      await manager.startSession(
        token: _jwt(subject: 'member-B', roles: ['ROLE_MUSICIAN']),
        username: 'other',
        accountStatus: 'ACTIVE',
      );
      reply.complete(_jsonResponse(statusCode: 403, payload: {'code': 1119}));
      await pending;
      await expectLater(
        api.get<void>('/api/v1/session/access'),
        throwsA(isA<ApiException>()),
      );
      expect(manager.session.userId, 'member-B');
    },
  );
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

ResponseBody _jsonResponse({
  required int statusCode,
  required Object payload,
  Map<String, List<String>> extraHeaders = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      ...extraHeaders,
    },
  );
}

typedef _ResponseFactory =
    FutureOr<ResponseBody> Function(RequestOptions options);

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
