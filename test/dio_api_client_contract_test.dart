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
import 'package:soundconnect_23_12_25codx/modules/auth/data/auth_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/media_gallery_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_search_repository_impl.dart';

part 'dio_api_client_contract_test_register_dio_api_client_transport_contract1.dart';
part 'dio_api_client_contract_test_register_dio_api_client_transport_contract2.dart';
part 'dio_api_client_contract_test_register_dio_api_client_contract3.dart';

void main() {
  _registerDioApiClientContract3();
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
