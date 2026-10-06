import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/jwt_claims.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_repository_impl.dart';

const _owner = '22222222-2222-4222-8222-222222222222';
const _other = '33333333-3333-4333-8333-333333333333';
const _notice = '11111111-1111-4111-8111-111111111111';

enum _Mutation { readAll, clearAll, read, delete }

String _jwt(
  String user, {
  String nonce = 'one',
  String role = 'ROLE_MUSICIAN',
  bool restricted = false,
}) {
  String encode(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({
    'sub': user,
    'exp': 4102444800,
    'nonce': nonce,
    if (restricted) ...{'scope': 'VENUE_APPLICATION', 'applicationId': _notice} else 'roles': [role],
  })}.fixture';
}

void main() {
  late _Tokens tokens;
  late AuthSessionManager sessions;
  late _Adapter adapter;
  late Dio dio;
  late NotificationRepositoryImpl repository;

  setUp(() {
    tokens = _Tokens();
    sessions = AuthSessionManager(
      tokenStore: tokens,
      sessionStore: _SessionStore(),
    );
    adapter = _Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    repository = NotificationRepositoryImpl(
      DioApiClient(dio: dio, tokenStore: tokens, sessionManager: sessions),
      sessions,
    );
  });
  tearDown(() {
    sessions.dispose();
    dio.close(force: true);
  });

  Future<void> login(
    String user, {
    String nonce = 'one',
    String role = 'ROLE_MUSICIAN',
    String status = 'ACTIVE',
    bool choice = false,
    bool restricted = false,
  }) => sessions.startSession(
    token: _jwt(user, nonce: nonce, role: role, restricted: restricted),
    username: 'fixture',
    accountStatus: status,
    requiresListenerProfileChoice: choice,
  );
  Future<Result<dynamic>> mutate(_Mutation operation) => switch (operation) {
    _Mutation.readAll => repository.markAllAsRead(),
    _Mutation.clearAll => repository.clearAllNotifications(),
    _Mutation.read => repository.markAsRead(notificationId: _notice),
    _Mutation.delete => repository.deleteNotification(notificationId: _notice),
  };

  for (final mutation in _Mutation.values) {
    for (final change in ['none', 'account', 'logout', 'relogin', 'role']) {
      test(
        '$mutation captures original bearer before queued $change',
        () async {
          await login(_owner);
          final result = mutate(mutation);
          if (change == 'logout' || change == 'relogin') {
            await sessions.logout();
          }
          if (change == 'account') await login(_other);
          if (change == 'relogin') await login(_owner, nonce: 'two');
          if (change == 'role') {
            await login(_owner, nonce: 'listener', role: 'ROLE_LISTENER');
          }
          final completed = await result;
          if (change == 'none') {
            expect(completed.isSuccess, isTrue);
            expect(adapter.requests, hasLength(1));
            expect(adapter.requests.single.owner, _owner);
            expect(adapter.requests.single.path, switch (mutation) {
              _Mutation.readAll => NotificationEndpoints.markAllRead,
              _Mutation.clearAll => NotificationEndpoints.clearAll,
              _Mutation.read => NotificationEndpoints.markRead(_notice),
              _Mutation.delete => NotificationEndpoints.delete(_notice),
            });
            expect(
              adapter.requests.single.method,
              mutation == _Mutation.clearAll || mutation == _Mutation.delete
                  ? 'DELETE'
                  : 'POST',
            );
          } else {
            expect(completed.isSuccess, isFalse);
            expect(completed.error?.code, 'api_session_fence');
            expect(adapter.requests, isEmpty);
          }
        },
      );
    }

    for (final blocked in [
      'guest',
      'inactive',
      'restricted',
      'profile-choice',
    ]) {
      test('$mutation rejects $blocked before transport', () async {
        if (blocked != 'guest') {
          await login(
            _owner,
            status: blocked == 'inactive'
                ? 'SUSPENDED'
                : blocked == 'restricted'
                ? 'PENDING_APPROVAL'
                : 'ACTIVE',
            role: blocked == 'profile-choice'
                ? 'ROLE_LISTENER'
                : 'ROLE_MUSICIAN',
            choice: blocked == 'profile-choice',
            restricted: blocked == 'restricted',
          );
        }
        final result = await mutate(mutation);
        expect(result.isSuccess, isFalse);
        expect(result.error?.code, 'api_session_fence');
        expect(adapter.requests, isEmpty);
      });
    }
  }

  for (final mutation in [_Mutation.readAll, _Mutation.clearAll]) {
    test('active listener keeps the authorized $mutation action', () async {
      await login(_owner, role: 'ROLE_LISTENER');
      final result = await mutate(mutation);
      expect(result.isSuccess, isTrue);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.owner, _owner);
    });
  }
}

class _Tokens implements TokenStore {
  String? value;
  @override
  Future<String?> readToken() async => value;
  @override
  Future<void> writeToken(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _SessionStore implements AuthSessionStore {
  AuthSessionMetadata? value;
  @override
  Future<AuthSessionMetadata?> read() async => value;
  @override
  Future<void> write(AuthSessionMetadata data) async {
    value = data;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <({String? owner, String method, String path})>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      owner: JwtClaims.tryParse(
        options.headers['Authorization']?.toString().replaceFirst(
          'Bearer ',
          '',
        ),
      )?.subject,
      method: options.method,
      path: options.path,
    ));
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'updated': 1, 'deleted': 1},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
