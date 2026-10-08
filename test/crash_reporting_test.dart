import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/diagnostics/app_diagnostics.dart';
import 'package:soundconnect_23_12_25codx/core/diagnostics/crash_reporting.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';

AppDiagnosticEvent event({
  String type = 'StateError',
  String source = 'flutter-framework',
  String? stack,
}) => AppDiagnosticEvent(
  severity: AppDiagnosticSeverity.error,
  source: source,
  errorType: type,
  stackTrace: StackTrace.fromString(
    stack ?? '#0 foo (package:soundconnect_23_12_25codx/core/test.dart:12:3)',
  ),
);

void main() {
  test(
    'sanitizer discards dynamic types, method names, paths, URLs and messages',
    () {
      final report = DiagnosticReport.sanitize(
        event(
          type: 'PrivateAccount123',
          source: 'bloc:PrivateAccount123',
          stack: '''
#0 privateUserMethod (package:soundconnect_23_12_25codx/core/test.dart:12:3)
#1 privateArguments (dart:async/future_impl.dart:10:2)
#2 foo (file:///Users/private/token.dart:1:2)
#3 foo (https://secret.example/api/private:1:2)
message package:soundconnect_23_12_25codx/private.dart:1:2
#4 foo (package:soundconnect_23_12_25codx/../../private.dart:1:2)
#5 foo (package:privateuser/secret.dart:1:2)
#6 foo (package:soundconnect_23_12_25codx/core/test.dart:12:3?token=secret)
''',
        ),
      );
      expect(report.source, 'BLOC');
      expect(report.errorType, 'ApplicationError');
      expect(report.frames, [
        'package:soundconnect_23_12_25codx/core/test.dart:12:3',
        'dart:async/future_impl.dart:10:2',
      ]);
      expect(report.frames.join('|'), isNot(contains('private')));
    },
  );

  test('sanitizer bounds traces and preserves fatal severity', () {
    final report = DiagnosticReport.sanitize(
      AppDiagnosticEvent(
        severity: AppDiagnosticSeverity.fatal,
        source: 'unhandled-zone',
        errorType: 'FormatException',
        stackTrace: StackTrace.fromString(
          List.generate(
            1000,
            (i) => '#$i f (dart:async/future_impl.dart:10:2)',
          ).join('\n'),
        ),
      ),
    );
    expect(report.frames, hasLength(40));
    expect(report.fatal, true);
    expect(report.source, 'UNHANDLED_ZONE');
  });

  test('throwing custom stack never breaks diagnostic dispatch', () {
    final report = DiagnosticReport.sanitize(
      AppDiagnosticEvent(
        severity: AppDiagnosticSeverity.error,
        source: 'unknown',
        errorType: 'StateError',
        stackTrace: _BadStack(),
      ),
    );
    expect(report.frames, isEmpty);
    expect(report.source, 'RECOVERABLE');
  });

  test(
    'four in-flight operations stay bounded across window rollover',
    () async {
      var elapsed = Duration.zero;
      final pending = List.generate(4, (_) => Completer<bool>());
      var writes = 0;
      final dispatcher = DiagnosticDispatcher(
        (_) => pending[writes++].future,
        elapsed: () => elapsed,
      );
      final tasks = <Future<bool>>[];
      for (final type in DiagnosticReport.errorTypes.take(4)) {
        tasks.add(dispatcher.dispatch(event(type: type)));
      }
      elapsed = const Duration(minutes: 1);
      expect(await dispatcher.dispatch(event(type: 'SocketException')), false);
      expect(writes, 4);
      for (final value in pending) {
        value.complete(true);
      }
      expect(await Future.wait(tasks), everyElement(true));
    },
  );

  test(
    'twenty-per-minute cap and per-signature dedup reset at one minute',
    () async {
      var elapsed = Duration.zero, writes = 0;
      final dispatcher = DiagnosticDispatcher((_) async {
        writes++;
        return true;
      }, elapsed: () => elapsed);
      for (final type in DiagnosticReport.errorTypes) {
        expect(await dispatcher.dispatch(event(type: type)), true);
      }
      expect(await dispatcher.dispatch(event(source: 'frame-timing')), false);
      expect(writes, 20);
      elapsed = const Duration(minutes: 1);
      expect(await dispatcher.dispatch(event()), true);
      expect(await dispatcher.dispatch(event()), false);
      expect(writes, 21);
    },
  );

  test('writer failure is swallowed and does not recursively retry', () async {
    var writes = 0;
    final dispatcher = DiagnosticDispatcher((_) {
      writes++;
      throw StateError('secret');
    });
    expect(await dispatcher.dispatch(event()), false);
    expect(await dispatcher.dispatch(event()), false);
    dispatcher.dispose();
    expect(await dispatcher.dispatch(event(type: 'FormatException')), false);
    expect(writes, 1);
  });

  group('authenticated collector', () {
    late _Sessions sessions;
    late _Api api;
    late MobileDiagnosticReporter reporter;
    const id = 'a102d00e-907d-4d4c-99b1-e51b3f30b160';
    setUp(() {
      sessions = _Sessions()..value = _session();
      api = _Api();
      reporter = MobileDiagnosticReporter(
        api: api,
        sessions: sessions,
        environment: 'local',
        createId: () => id,
        delay: (_) async {},
      );
    });
    tearDown(() {
      reporter.dispose();
      sessions.dispose();
    });

    test(
      'only safe schema goes in body while auth uses transport fence',
      () async {
        expect(await reporter.report(event()), true);
        final call = api.calls.single;
        expect(call.path, '/api/v1/diagnostics/mobile');
        expect(call.method, ApiHttpMethod.post);
        expect(call.body.keys.toSet(), {
          'eventId',
          'severity',
          'source',
          'errorType',
          'frames',
          'environment',
        });
        expect(call.context!.expectedSessionKey, 'private-account');
        expect(call.context!.expectedToken, 'private-token');
        expect(call.body.toString(), isNot(contains('private')));
      },
    );

    test('guest errors are discarded and never replayed after login', () async {
      sessions.value = const AuthSession.guest();
      expect(await reporter.report(event()), false);
      sessions.value = _session();
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, isEmpty);
      expect(await reporter.report(event()), true);
    });

    test(
      'pending profile choice and invalid environment cannot send',
      () async {
        sessions.value = _session(choice: true);
        expect(await reporter.report(event()), false);
        sessions.value = _session();
        final invalid = MobileDiagnosticReporter(
          api: api,
          sessions: sessions,
          environment: 'private-env',
        );
        expect(await invalid.report(event()), false);
        invalid.dispose();
        expect(api.calls, isEmpty);
      },
    );

    test(
      'one transient retry reuses event ID and original session fence',
      () async {
        api.respond = (call) async {
          if (api.calls.length == 1) {
            throw ApiException(
              const AppError(
                code: '1115',
                message: 'private server error',
                retryAfter: Duration(seconds: 5),
              ),
            );
          }
          return {'eventId': call.body['eventId'], 'accepted': true};
        };
        expect(await reporter.report(event()), true);
        expect(api.calls, hasLength(2));
        expect(api.calls.map((c) => c.body['eventId']), everyElement(id));
        expect(
          api.calls.map((c) => c.context!.expectedToken),
          everyElement('private-token'),
        );
      },
    );

    test('repeated network failure stops after two attempts', () async {
      api.respond = (_) async => throw ApiException(
        const AppError(code: 'network', message: 'private host'),
      );
      expect(await reporter.report(event()), false);
      expect(api.calls, hasLength(2));
    });

    test(
      'permanent failure does not retry despite a misleading retry header',
      () async {
        api.respond = (_) async => throw ApiException(
          const AppError(
            code: '401',
            message: 'unauthorized',
            retryAfter: Duration(seconds: 5),
          ),
        );
        expect(await reporter.report(event()), false);
        expect(api.calls, hasLength(1));
      },
    );

    test(
      'long server cooldown is honored by dropping instead of retrying early',
      () async {
        api.respond = (_) async => throw ApiException(
          const AppError(
            code: '429',
            message: 'rate limited',
            retryAfter: Duration(minutes: 1),
          ),
        );
        expect(await reporter.report(event()), false);
        expect(api.calls, hasLength(1));
      },
    );

    test(
      'logout/relogin during retry never sends the old event under a new token',
      () async {
        reporter.dispose();
        final delayed = Completer<void>();
        reporter = MobileDiagnosticReporter(
          api: api,
          sessions: sessions,
          environment: 'local',
          createId: () => id,
          delay: (_) => delayed.future,
        );
        api.respond = (_) async => throw ApiException(
          const AppError(code: 'network', message: 'offline'),
        );
        final result = reporter.report(event());
        await Future<void>.delayed(Duration.zero);
        sessions.revision++;
        sessions.value = _session(token: 'new-token');
        delayed.complete();
        expect(await result, false);
        expect(api.calls, hasLength(1));
      },
    );

    test(
      'credential intent fences even a still-identical session snapshot',
      () async {
        reporter.dispose();
        reporter = MobileDiagnosticReporter(
          api: api,
          sessions: sessions,
          environment: 'local',
          delay: (_) async {
            sessions.revision++;
          },
        );
        api.respond = (_) async => throw ApiException(
          const AppError(code: 'network', message: 'offline'),
        );
        expect(await reporter.report(event()), false);
        expect(api.calls, hasLength(1));
      },
    );

    test(
      'late success from prior session is not an acceptance receipt',
      () async {
        final response = Completer<Object?>();
        api.respond = (_) => response.future;
        final result = reporter.report(event());
        sessions.value = _session(token: 'new-token');
        response.complete({'eventId': id, 'accepted': true});
        expect(await result, false);
      },
    );

    test(
      'HTTP success without exact receipt is not reported as acceptance',
      () async {
        api.respond = (_) async => {
          'eventId': 'another-event',
          'accepted': true,
        };
        expect(await reporter.report(event()), false);
      },
    );
  });

  test(
    'real Dio stops a credential-intent change during token storage await before dispatch',
    () async {
      final token =
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'private-account', 'exp': 4102444800}))).replaceAll('=', '')}.signature';
      final sessions = _Sessions()..value = _session(token: token);
      final tokens = _PausedTokens();
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      final client = DioApiClient(
        dio: dio,
        tokenStore: tokens,
        sessionManager: sessions,
      );
      final reporter = MobileDiagnosticReporter(
        api: client,
        sessions: sessions,
        environment: 'local',
      );
      final result = reporter.report(event());
      await Future<void>.delayed(Duration.zero);
      sessions.revision++;
      tokens.token.complete(token);
      expect(await result, false);
      expect(adapter.calls, 0);
      reporter.dispose();
      sessions.dispose();
      dio.close();
    },
  );

  for (final status in [202, 401]) {
    test(
      'real Dio fences late $status without mutating the replacement credentials',
      () async {
        final token =
            'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'private-account', 'exp': 4102444800}))).replaceAll('=', '')}.signature';
        final sessions = _Sessions()..value = _session(token: token);
        final tokens = _PausedTokens()..token.complete(token);
        final response = Completer<ResponseBody>();
        final entered = Completer<void>();
        final adapter = _Adapter()
          ..respond = (_) {
            entered.complete();
            return response.future;
          };
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokens,
          sessionManager: sessions,
        );
        final result = client.request<Object?>(
          ApiHttpMethod.post,
          '/api/v1/diagnostics/mobile',
          body: {},
          requestContext: ApiRequestContext(
            expectedSessionKey: sessions.session.userId,
            expectedToken: token,
            expectedCredentialRevision: 0,
          ),
        );
        final verified = expectLater(
          result,
          throwsA(
            isA<ApiException>().having(
              (e) => e.error.code,
              'code',
              'api_session_fence',
            ),
          ),
        );
        await entered.future;
        sessions.revision++;
        response.complete(
          ResponseBody.fromString(
            jsonEncode({'success': status == 202, 'code': status, 'data': {}}),
            status,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        await verified;
        expect(sessions.rejectedTokens, 0);
        sessions.dispose();
        dio.close();
      },
    );
  }
}

class _BadStack implements StackTrace {
  @override
  String toString() => throw StateError('secret');
}

AuthSession _session({String token = 'private-token', bool choice = false}) =>
    AuthSession.authenticated(
      token: token,
      userId: 'private-account',
      username: 'private-user',
      accountStatus: 'ACTIVE',
      roles: ['ROLE_MUSICIAN'],
      permissions: [],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      isAdmin: false,
      requiresListenerProfileChoice: choice,
    );

class _Sessions extends AuthSessionManager {
  _Sessions() : super(tokenStore: _Tokens(), sessionStore: _Metadata());
  AuthSession value = const AuthSession.guest();
  int revision = 0;
  int rejectedTokens = 0;
  @override
  AuthSession get session => value;
  @override
  int get credentialRevision => revision;
  @override
  Future<void> rejectUnauthorizedToken(String? rejectedToken) async {
    rejectedTokens++;
  }
}

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<void> writeToken(String token) async {}
  @override
  Future<void> clear() async {}
}

class _PausedTokens extends _Tokens {
  final token = Completer<String?>();
  @override
  Future<String?> readToken() => token.future;
}

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  Future<ResponseBody> Function(RequestOptions)? respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (respond != null) return respond!(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'eventId': (options.data as Map)['eventId'], 'accepted': true},
      }),
      202,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Metadata implements AuthSessionStore {
  @override
  Future<AuthSessionMetadata?> read() async => null;
  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
  @override
  Future<void> clear() async {}
}

class _Call {
  _Call(this.method, this.path, this.body, this.context);
  final ApiHttpMethod method;
  final String path;
  final Map<String, Object> body;
  final ApiRequestContext? context;
}

class _Api implements ApiClient {
  final calls = <_Call>[];
  Future<Object?> Function(_Call)? respond;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    final call = _Call(
      method,
      path,
      Map<String, Object>.from(body! as Map),
      requestContext,
    );
    calls.add(call);
    final data = respond != null
        ? await respond!(call)
        : {'eventId': call.body['eventId'], 'accepted': true};
    return data as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
