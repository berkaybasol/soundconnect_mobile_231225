import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/base_response.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/core/push/firebase_push_provider.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_delivered_reconciler.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_delivery_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

const owner = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';
const epoch = '20000000-0000-4000-8000-000000000001';
const readId = '30000000-0000-4000-8000-000000000001';
const unreadId = '30000000-0000-4000-8000-000000000002';
const foreignId = '30000000-0000-4000-8000-000000000003';

AuthSession signedIn(String id, {String? token, bool needsChoice = false}) =>
    AuthSession.authenticated(
      token: token ?? 'test-$id',
      userId: id,
      username: 'fixture',
      accountStatus: 'ACTIVE',
      roles: const ['ROLE_MUSICIAN'],
      permissions: const [],
      expiresAt: DateTime(2099),
      isAdmin: false,
      requiresListenerProfileChoice: needsChoice,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Sessions sessions;
  late _Provider native;
  late _Api api;
  late PushDeliveredReconciler reconciler;
  setUp(() {
    sessions = _Sessions()..value = signedIn(owner);
    native = _Provider();
    api = _Api();
    reconciler = PushDeliveredReconciler(sessions, native, api);
  });
  tearDown(() {
    reconciler.dispose();
    sessions.dispose();
  });

  test(
    'warm resume removes confirmed read only, keeps unread and binding',
    () async {
      await reconciler.reconcile();
      expect(native.active, {unreadId});
      expect(native.lastEpoch, epoch);
      expect(api.requested, [readId, unreadId]);
      expect(api.captured?.userId, owner);
      expect(native.snapshotCalls, 1);
    },
  );
  test(
    'failed comparison preserves every OS alert and retries next resume',
    () async {
      api.fail = true;
      await reconciler.reconcile();
      expect(native.active, {readId, unreadId});
      api.fail = false;
      await reconciler.reconcile();
      expect(native.active, {unreadId});
    },
  );
  test('late response after account change cannot dismiss', () async {
    api.block = Completer<Set<String>>();
    final pending = reconciler.reconcile();
    await api.started.future;
    sessions.value = signedIn(other);
    api.block!.complete({readId});
    await pending;
    expect(native.active, {readId, unreadId});
    expect(native.dismissCalls, 0);
  });
  test('same owner with replacement token fences old response', () async {
    api.block = Completer<Set<String>>();
    final pending = reconciler.reconcile();
    await api.started.future;
    sessions.value = signedIn(owner, token: 'replacement');
    api.block!.complete({readId});
    await pending;
    expect(native.dismissCalls, 0);
  });
  test('native epoch accompanies dismissal after same owner relogin', () async {
    api.block = Completer<Set<String>>();
    final pending = reconciler.reconcile();
    await api.started.future;
    native.currentEpoch = other;
    api.block!.complete({readId});
    await pending;
    expect(native.lastEpoch, epoch);
    expect(native.active, {readId, unreadId});
  });
  test(
    'API cannot cancel IDs absent from the captured native snapshot',
    () async {
      api.result = {readId, foreignId};
      await reconciler.reconcile();
      expect(native.dismissed, [readId]);
    },
  );
  test(
    'concurrent ACK schedules one fresh comparison after pending one',
    () async {
      api.block = Completer<Set<String>>();
      final first = reconciler.reconcile();
      await api.started.future;
      final next = reconciler.reconcile();
      expect(identical(first, next), isTrue);
      api.result = {unreadId};
      final block = api.block!;
      api.block = null;
      block.complete({readId});
      await first;
      expect(api.calls, 2);
      expect(native.active, isEmpty);
    },
  );
  test('dispose while network is pending prevents cancellation', () async {
    api.block = Completer<Set<String>>();
    final pending = reconciler.reconcile();
    await api.started.future;
    reconciler.dispose();
    api.block!.complete({readId});
    await pending;
    expect(native.dismissCalls, 0);
  });
  test('empty tray needs no HTTP request', () async {
    native.active.clear();
    await reconciler.reconcile();
    expect(api.calls, 0);
  });
  for (final session in [
    const AuthSession.guest(),
    signedIn(owner, needsChoice: true),
  ]) {
    test(
      'ineligible session ${session.isAuthenticated} never reads tray or API',
      () async {
        sessions.value = session;
        await reconciler.reconcile();
        expect(native.snapshotCalls, 0);
        expect(api.calls, 0);
      },
    );
  }
  test('wrong native owner is ignored without sending IDs', () async {
    native.ownerId = other;
    await reconciler.reconcile();
    expect(api.calls, 0);
    expect(native.dismissCalls, 0);
  });

  test(
    'HTTP comparison is bounded, session fenced, and does not ACK',
    () async {
      final client = _Client();
      final http = HttpPushDeliveryApi(client);
      expect(await http.dismissedIds(signedIn(owner), [readId, unreadId]), {
        readId,
      });
      expect(client.path, '/api/v1/user/notifications/delivery-state');
      expect(client.method, ApiHttpMethod.post);
      expect(client.context?.expectedSessionKey, owner);
      expect(client.context?.expectedToken, 'test-$owner');
      expect(client.body, {
        'notificationIds': [readId, unreadId],
      });
      expect(await http.dismissedIds(signedIn(owner), []), isEmpty);
      expect(client.calls, 1);
      await expectLater(
        http.dismissedIds(signedIn(owner), List.filled(101, readId)),
        throwsArgumentError,
      );
      await expectLater(
        http.dismissedIds(signedIn(owner), ['bad-id']),
        throwsArgumentError,
      );
      expect(client.calls, 1);
    },
  );
  test(
    'real Dio BaseResponse decoder consumes the server envelope once',
    () async {
      String encode(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${encode({'alg': 'none'})}.${encode({'sub': owner, 'exp': 4102444800})}.fixture';
      final captured = signedIn(owner, token: token);
      sessions.value = captured;
      final adapter = _DeliveryAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final client = DioApiClient(
        dio: dio,
        tokenStore: _MemoryTokens(token),
        sessionManager: sessions,
      );
      expect(
        await HttpPushDeliveryApi(
          client,
        ).dismissedIds(captured, [readId, unreadId]),
        {readId},
      );
      expect(adapter.method, 'POST');
      expect(adapter.authorization, 'Bearer $token');
      expect(adapter.path, '/api/v1/user/notifications/delivery-state');
    },
  );

  for (final response in [
    {
      'data': {
        'dismissedIds': [foreignId],
      },
    },
    {
      'data': {
        'dismissedIds': ['bad-id'],
      },
    },
    {'data': {}},
  ]) {
    test('malformed or foreign response is rejected: $response', () async {
      final client = _Client()..response = response;
      await expectLater(
        HttpPushDeliveryApi(client).dismissedIds(signedIn(owner), [readId]),
        throwsFormatException,
      );
    });
  }
  test(
    'Android bridge captures owner epoch and cancels exactly selected IDs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('com.soundconnect/push_delivery');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'deliveredSnapshot') {
              return {
                'recipientId': owner,
                'bindingEpoch': epoch,
                'notificationIds': [readId, unreadId],
              };
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final provider = FirebasePushProvider();
      final snapshot = (await provider.deliveredSnapshot(owner))!;
      await provider.dismissDelivered(snapshot, [readId]);
      expect(calls.map((call) => call.method), [
        'deliveredSnapshot',
        'dismissDelivered',
      ]);
      expect(calls.last.arguments, {
        'recipientId': owner,
        'bindingEpoch': epoch,
        'notificationIds': [readId],
      });
    },
  );
}

class _Sessions extends AuthSessionManager {
  _Sessions() : super(tokenStore: _Tokens(), sessionStore: _SessionStore());
  AuthSession value = const AuthSession.guest();
  @override
  AuthSession get session => value;
}

class _Tokens implements TokenStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryTokens extends _Tokens {
  _MemoryTokens(this.token);
  final String token;
  @override
  Future<String?> readToken() async => token;
}

class _DeliveryAdapter implements HttpClientAdapter {
  String? method, path, authorization;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.path;
    authorization = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'code': 200,
        'data': {
          'dismissedIds': [readId],
        },
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

class _SessionStore implements AuthSessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Provider implements PushDeliveredProvider {
  final active = <String>{readId, unreadId};
  String ownerId = owner, currentEpoch = epoch;
  String? lastEpoch;
  List<String> dismissed = [];
  int snapshotCalls = 0, dismissCalls = 0;
  @override
  Future<PushDeliveredSnapshot?> deliveredSnapshot(String recipientId) async {
    snapshotCalls++;
    return PushDeliveredSnapshot(
      recipientId: ownerId,
      bindingEpoch: currentEpoch,
      notificationIds: active.toList(),
    );
  }

  @override
  Future<void> dismissDelivered(
    PushDeliveredSnapshot snapshot,
    List<String> ids,
  ) async {
    dismissCalls++;
    lastEpoch = snapshot.bindingEpoch;
    dismissed = ids;
    if (snapshot.bindingEpoch == currentEpoch &&
        snapshot.recipientId == ownerId) {
      active.removeAll(ids);
    }
  }
}

class _Api implements PushDeliveryApi {
  int calls = 0;
  bool fail = false;
  Set<String> result = {readId};
  List<String>? requested;
  AuthSession? captured;
  Completer<Set<String>>? block;
  final started = Completer<void>();
  @override
  Future<Set<String>> dismissedIds(
    AuthSession session,
    List<String> ids,
  ) async {
    calls++;
    requested = ids;
    captured = session;
    if (!started.isCompleted) started.complete();
    if (fail) throw StateError('offline');
    return await (block?.future ?? Future.value(result));
  }
}

class _Client implements ApiClient {
  Object response = {
    'data': {
      'dismissedIds': [readId],
    },
  };
  int calls = 0;
  String? path;
  ApiHttpMethod? method;
  Object? body;
  ApiRequestContext? context;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.body = body;
    context = requestContext;
    return BaseResponse<T>.fromJson(
          response as Map<String, dynamic>,
          decoder,
        ).data
        as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
