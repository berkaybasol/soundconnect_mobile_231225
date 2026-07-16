import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/login_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/register_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resend_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/verify_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_state.dart';

void main() {
  group('AuthCubit edge cases', () {
    test('login persistence failure emits a safe terminal failure', () async {
      final _ScriptedAuthRepository repository = _ScriptedAuthRepository(
        loginResult: const Result<LoginResult>.success(
          LoginResult(token: 'access-token'),
        ),
      );
      final _MemoryTokenStore tokenStore = _MemoryTokenStore(failWrite: true);
      final AuthCubit cubit = _cubit(repository, tokenStore);
      addTearDown(cubit.close);

      final Future<void> expectation = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<AuthState>()
              .having(
                (AuthState state) => state.status,
                'status',
                AuthStatus.loading,
              )
              .having(
                (AuthState state) => state.action,
                'action',
                AuthAction.login,
              ),
          isA<AuthState>()
              .having(
                (AuthState state) => state.status,
                'status',
                AuthStatus.failure,
              )
              .having(
                (AuthState state) => state.error?.code,
                'error.code',
                'auth_session_persist_failed',
              )
              .having(
                (AuthState state) => state.loginResult,
                'loginResult',
                isNull,
              ),
        ]),
      );

      await cubit.login(username: 'listener', password: 'secret');
      await expectation;

      expect(tokenStore.writeCount, 1);
      expect(tokenStore.value, isNull);
    });

    test(
      'logout idempotently clears the fallback token store and resets payloads',
      () async {
        final _ScriptedAuthRepository repository = _ScriptedAuthRepository();
        final _MemoryTokenStore tokenStore = _MemoryTokenStore(value: 'token');
        final AuthCubit cubit = _cubit(repository, tokenStore);
        addTearDown(cubit.close);

        await Future.wait(<Future<void>>[cubit.logout(), cubit.logout()]);
        await cubit.logout();

        expect(tokenStore.clearCount, 1);
        expect(tokenStore.value, isNull);
        expect(cubit.state.status, AuthStatus.success);
        expect(cubit.state.action, AuthAction.logout);
        expect(cubit.state.error, isNull);
        expect(cubit.state.loginResult, isNull);
        expect(cubit.state.registerResult, isNull);
        expect(cubit.state.resendResult, isNull);
      },
    );

    test(
      'external session logout clears the previous login result token',
      () async {
        final String token = _jwt(
          subject: 'listener-user-id',
          roles: const <String>['ROLE_LISTENER'],
        );
        final _MemoryTokenStore managerTokenStore = _MemoryTokenStore();
        final _MemorySessionStore metadataStore = _MemorySessionStore();
        final AuthSessionManager sessionManager = AuthSessionManager(
          tokenStore: managerTokenStore,
          sessionStore: metadataStore,
        );
        addTearDown(sessionManager.dispose);
        final AuthCubit cubit = _cubit(
          _ScriptedAuthRepository(
            loginResult: Result<LoginResult>.success(
              LoginResult(token: token, username: 'listener'),
            ),
          ),
          _MemoryTokenStore(),
          sessionManager: sessionManager,
        );
        addTearDown(cubit.close);

        await cubit.login(username: 'listener', password: 'password');

        expect(cubit.state.loginResult?.token, token);
        expect(sessionManager.session.isAuthenticated, isTrue);

        final List<AuthState> emissions = <AuthState>[];
        final subscription = cubit.stream.listen(emissions.add);
        addTearDown(subscription.cancel);

        await sessionManager.logout();

        expect(emissions, hasLength(1));
        expect(cubit.state.status, AuthStatus.success);
        expect(cubit.state.action, AuthAction.logout);
        expect(cubit.state.message, isNull);
        expect(cubit.state.error, isNull);
        expect(cubit.state.loginResult, isNull);
        expect(cubit.state.registerResult, isNull);
        expect(cubit.state.resendResult, isNull);
      },
    );

    test(
      'close removes the session listener and prevents later emits',
      () async {
        final String token = _jwt(
          subject: 'listener-user-id',
          roles: const <String>['ROLE_LISTENER'],
        );
        final _TrackingAuthSessionManager sessionManager =
            _TrackingAuthSessionManager(
              tokenStore: _MemoryTokenStore(),
              sessionStore: _MemorySessionStore(),
            );
        addTearDown(sessionManager.dispose);
        await sessionManager.startSession(
          token: token,
          username: 'listener',
          accountStatus: 'ACTIVE',
        );
        final AuthCubit cubit = _cubit(
          _ScriptedAuthRepository(),
          _MemoryTokenStore(),
          sessionManager: sessionManager,
        );

        final List<AuthState> emissions = <AuthState>[];
        final subscription = cubit.stream.listen(emissions.add);
        addTearDown(subscription.cancel);

        expect(sessionManager.activeListenerCount, 1);

        await cubit.close();
        await sessionManager.logout();

        expect(sessionManager.activeListenerCount, 0);
        expect(sessionManager.removeListenerCount, 1);
        expect(emissions, isEmpty);
        expect(cubit.state.status, AuthStatus.idle);
        expect(cubit.state.action, AuthAction.none);
      },
    );

    test('initial guest manager notifications do not emit logout', () async {
      final AuthSessionManager sessionManager = AuthSessionManager(
        tokenStore: _MemoryTokenStore(),
        sessionStore: _MemorySessionStore(),
      );
      addTearDown(sessionManager.dispose);
      final AuthCubit cubit = _cubit(
        _ScriptedAuthRepository(),
        _MemoryTokenStore(),
        sessionManager: sessionManager,
      );
      addTearDown(cubit.close);
      final List<AuthState> emissions = <AuthState>[];
      final subscription = cubit.stream.listen(emissions.add);
      addTearDown(subscription.cancel);

      await sessionManager.restore(tokenOverride: Future<String?>.value(null));

      expect(emissions, isEmpty);
      expect(cubit.state.status, AuthStatus.idle);
      expect(cubit.state.action, AuthAction.none);
    });

    test(
      'register failure keeps its typed error and forwards all fields',
      () async {
        const AppError conflict = AppError(
          code: '409',
          message: 'Account already exists',
        );
        final _ScriptedAuthRepository repository = _ScriptedAuthRepository(
          registerResult: const Result<RegisterResult>.failure(conflict),
        );
        final AuthCubit cubit = _cubit(repository, _MemoryTokenStore());
        addTearDown(cubit.close);

        await cubit.register(
          username: 'venue',
          email: 'venue@example.com',
          password: 'password',
          rePassword: 'password',
          role: 'ROLE_VENUE',
          venueName: 'Venue',
          venueAddress: 'Address',
          phone: '5551112233',
          cityId: 'city-1',
          districtId: 'district-1',
          neighborhoodId: 'neighborhood-1',
        );

        expect(cubit.state.status, AuthStatus.failure);
        expect(cubit.state.action, AuthAction.register);
        expect(cubit.state.error, same(conflict));
        expect(repository.lastRegister?['username'], 'venue');
        expect(repository.lastRegister?['email'], 'venue@example.com');
        expect(repository.lastRegister?['password'], 'password');
        expect(repository.lastRegister?['rePassword'], 'password');
        expect(repository.lastRegister?['role'], 'ROLE_VENUE');
        expect(repository.lastRegister?['venueName'], 'Venue');
        expect(repository.lastRegister?['venueAddress'], 'Address');
        expect(repository.lastRegister?['phone'], '5551112233');
        expect(repository.lastRegister?['cityId'], 'city-1');
        expect(repository.lastRegister?['districtId'], 'district-1');
        expect(repository.lastRegister?['neighborhoodId'], 'neighborhood-1');
      },
    );

    test(
      'verify success emits success even though its payload is null',
      () async {
        final AuthCubit cubit = _cubit(
          _ScriptedAuthRepository(
            verifyResult: const Result<void>.success(null),
          ),
          _MemoryTokenStore(),
        );
        addTearDown(cubit.close);

        await cubit.verifyCode(email: 'user@example.com', code: '012345');

        expect(cubit.state.status, AuthStatus.success);
        expect(cubit.state.action, AuthAction.verify);
        expect(cubit.state.error, isNull);
      },
    );

    test(
      'resend failure emits failure without a stale resend payload',
      () async {
        const AppError throttled = AppError(
          code: '429',
          message: 'Try again later',
        );
        final AuthCubit cubit = _cubit(
          _ScriptedAuthRepository(
            resendResult: const Result<ResendCodeResult>.failure(throttled),
          ),
          _MemoryTokenStore(),
        );
        addTearDown(cubit.close);

        await cubit.resendCode(email: 'user@example.com');

        expect(cubit.state.status, AuthStatus.failure);
        expect(cubit.state.action, AuthAction.resend);
        expect(cubit.state.error, same(throttled));
        expect(cubit.state.resendResult, isNull);
      },
    );

    test(
      'session manager is the sole login and logout credential owner',
      () async {
        final String token = _jwt(
          subject: 'venue-user-id',
          roles: const <String>['ROLE_VENUE'],
        );
        final _MemoryTokenStore managerTokenStore = _MemoryTokenStore();
        final _MemorySessionStore metadataStore = _MemorySessionStore();
        var endedCount = 0;
        final AuthSessionManager sessionManager = AuthSessionManager(
          tokenStore: managerTokenStore,
          sessionStore: metadataStore,
          onSessionEnded: () async => endedCount += 1,
        );
        addTearDown(sessionManager.dispose);
        final _MemoryTokenStore fallbackTokenStore = _MemoryTokenStore();
        final _ScriptedAuthRepository repository = _ScriptedAuthRepository(
          loginResult: Result<LoginResult>.success(
            LoginResult(
              token: token,
              status: UserStatus.pendingVenueRequest,
              username: 'venue-display-name',
            ),
          ),
        );
        final AuthCubit cubit = _cubit(
          repository,
          fallbackTokenStore,
          sessionManager: sessionManager,
        );
        addTearDown(cubit.close);

        await cubit.login(username: 'venue-login', password: 'secret');

        expect(cubit.state.status, AuthStatus.success);
        expect(sessionManager.session.userId, 'venue-user-id');
        expect(sessionManager.session.username, 'venue-display-name');
        expect(sessionManager.session.isPendingVenue, isTrue);
        expect(managerTokenStore.value, token);
        expect(metadataStore.value?.accountStatus, 'PENDING_VENUE_REQUEST');
        expect(fallbackTokenStore.writeCount, 0);

        await cubit.logout();

        expect(sessionManager.session.isAuthenticated, isFalse);
        expect(managerTokenStore.value, isNull);
        expect(metadataStore.value, isNull);
        expect(endedCount, 1);
        expect(fallbackTokenStore.clearCount, 0);
      },
    );
  });

  group('AuthState copyWith boundaries', () {
    test(
      'omitted fields are preserved while explicit null clears payloads',
      () {
        const LoginResult login = LoginResult(token: 'token');
        const RegisterResult register = RegisterResult(
          email: 'user@example.com',
          status: UserStatus.inactive,
          otpTtlSeconds: 90,
          mailQueued: true,
        );
        const ResendCodeResult resend = ResendCodeResult(
          otpTtlSeconds: 90,
          mailQueued: true,
          cooldownSeconds: 30,
        );
        const AppError error = AppError(code: 'x', message: 'failure');
        const AuthState state = AuthState(
          status: AuthStatus.failure,
          action: AuthAction.resend,
          message: 'message',
          error: error,
          loginResult: login,
          registerResult: register,
          resendResult: resend,
        );

        final AuthState preserved = state.copyWith(status: AuthStatus.loading);
        final AuthState cleared = preserved.copyWith(
          message: null,
          error: null,
          loginResult: null,
          registerResult: null,
          resendResult: null,
        );

        expect(preserved.action, AuthAction.resend);
        expect(preserved.message, 'message');
        expect(preserved.error, same(error));
        expect(preserved.loginResult, same(login));
        expect(preserved.registerResult, same(register));
        expect(preserved.resendResult, same(resend));
        expect(cleared.message, isNull);
        expect(cleared.error, isNull);
        expect(cleared.loginResult, isNull);
        expect(cleared.registerResult, isNull);
        expect(cleared.resendResult, isNull);
      },
    );
  });
}

AuthCubit _cubit(
  _ScriptedAuthRepository repository,
  TokenStore tokenStore, {
  AuthSessionManager? sessionManager,
}) {
  return AuthCubit(
    loginUseCase: LoginUseCase(repository),
    registerUseCase: RegisterUseCase(repository),
    verifyCodeUseCase: VerifyCodeUseCase(repository),
    resendCodeUseCase: ResendCodeUseCase(repository),
    tokenStore: tokenStore,
    sessionManager: sessionManager,
  );
}

class _ScriptedAuthRepository implements AuthRepository {
  _ScriptedAuthRepository({
    Result<LoginResult>? loginResult,
    Result<RegisterResult>? registerResult,
    Result<void>? verifyResult,
    Result<ResendCodeResult>? resendResult,
  }) : _loginResult =
           loginResult ??
           const Result<LoginResult>.failure(
             AppError(code: 'unused', message: 'Unused login'),
           ),
       _registerResult =
           registerResult ??
           const Result<RegisterResult>.failure(
             AppError(code: 'unused', message: 'Unused register'),
           ),
       _verifyResult =
           verifyResult ??
           const Result<void>.failure(
             AppError(code: 'unused', message: 'Unused verify'),
           ),
       _resendResult =
           resendResult ??
           const Result<ResendCodeResult>.failure(
             AppError(code: 'unused', message: 'Unused resend'),
           );

  final Result<LoginResult> _loginResult;
  final Result<RegisterResult> _registerResult;
  final Result<void> _verifyResult;
  final Result<ResendCodeResult> _resendResult;
  Map<String, Object?>? lastRegister;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async => _loginResult;

  @override
  Future<Result<RegisterResult>> register({
    required String username,
    required String email,
    required String password,
    required String rePassword,
    required String role,
    String? venueName,
    String? venueAddress,
    String? phone,
    String? cityId,
    String? districtId,
    String? neighborhoodId,
  }) async {
    lastRegister = <String, Object?>{
      'username': username,
      'email': email,
      'password': password,
      'rePassword': rePassword,
      'role': role,
      'venueName': venueName,
      'venueAddress': venueAddress,
      'phone': phone,
      'cityId': cityId,
      'districtId': districtId,
      'neighborhoodId': neighborhoodId,
    };
    return _registerResult;
  }

  @override
  Future<Result<ResendCodeResult>> resendCode({required String email}) async =>
      _resendResult;

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  }) async => _verifyResult;
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.value, this.failWrite = false});

  String? value;
  final bool failWrite;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    value = null;
  }

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async {
    writeCount += 1;
    if (failWrite) throw StateError('secure storage write failed');
    value = token;
  }
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

class _TrackingAuthSessionManager extends AuthSessionManager {
  _TrackingAuthSessionManager({
    required super.tokenStore,
    required super.sessionStore,
  });

  int addListenerCount = 0;
  int removeListenerCount = 0;

  int get activeListenerCount => addListenerCount - removeListenerCount;

  @override
  void addListener(VoidCallback listener) {
    addListenerCount += 1;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCount += 1;
    super.removeListener(listener);
  }
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
