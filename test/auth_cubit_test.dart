import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/verify_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/login_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/register_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/reset_password_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resend_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/update_username_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/verify_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_state.dart';

void main() {
  group('AuthCubit', () {
    test('login success emits loading then success and stores token', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        loginResponse: const Result<LoginResult>.success(
          LoginResult(token: 'token-123'),
        ),
      );
      final _InMemoryTokenStore tokenStore = _InMemoryTokenStore();
      final AuthCubit cubit = _createCubit(
        repository: repository,
        tokenStore: tokenStore,
      );

      final Future<void> expectation = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.loading)
              .having((AuthState s) => s.action, 'action', AuthAction.login),
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.success)
              .having((AuthState s) => s.action, 'action', AuthAction.login)
              .having(
                (AuthState s) => s.loginResult?.token,
                'token',
                'token-123',
              ),
        ]),
      );

      await cubit.login(username: 'user', password: 'pass');
      await expectation;

      expect(tokenStore.token, 'token-123');
      expect(tokenStore.writeCount, 1);

      await cubit.close();
    });

    test(
      'login failure emits loading then failure without token write',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          loginResponse: const Result<LoginResult>.failure(
            AppError(code: '401', message: 'Unauthorized'),
          ),
        );
        final _InMemoryTokenStore tokenStore = _InMemoryTokenStore();
        final AuthCubit cubit = _createCubit(
          repository: repository,
          tokenStore: tokenStore,
        );

        final Future<void> expectation = expectLater(
          cubit.stream,
          emitsInOrder(<Matcher>[
            isA<AuthState>()
                .having((AuthState s) => s.status, 'status', AuthStatus.loading)
                .having((AuthState s) => s.action, 'action', AuthAction.login),
            isA<AuthState>()
                .having((AuthState s) => s.status, 'status', AuthStatus.failure)
                .having((AuthState s) => s.action, 'action', AuthAction.login)
                .having((AuthState s) => s.error?.code, 'error.code', '401'),
          ]),
        );

        await cubit.login(username: 'user', password: 'wrong');
        await expectation;

        expect(tokenStore.writeCount, 0);
        expect(tokenStore.token, isNull);

        await cubit.close();
      },
    );

    test('login success preserves pending venue status', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        loginResponse: const Result<LoginResult>.success(
          LoginResult(
            token: 'pending-token',
            status: UserStatus.pendingVenueRequest,
          ),
        ),
      );
      final AuthCubit cubit = _createCubit(
        repository: repository,
        tokenStore: _InMemoryTokenStore(),
      );

      final Future<void> expectation = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.loading)
              .having((AuthState s) => s.action, 'action', AuthAction.login),
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.success)
              .having((AuthState s) => s.action, 'action', AuthAction.login)
              .having(
                (AuthState s) => s.loginResult?.status,
                'login.status',
                UserStatus.pendingVenueRequest,
              ),
        ]),
      );

      await cubit.login(username: 'venue', password: 'pass');
      await expectation;

      await cubit.close();
    });

    test('register success stores register result in state', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        registerResponse: const Result<RegisterResult>.success(
          RegisterResult(
            email: 'demo@example.com',
            status: UserStatus.pendingVenueRequest,
            otpTtlSeconds: 120,
            mailQueued: true,
          ),
        ),
      );
      final AuthCubit cubit = _createCubit(
        repository: repository,
        tokenStore: _InMemoryTokenStore(),
      );

      final Future<void> expectation = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.loading)
              .having((AuthState s) => s.action, 'action', AuthAction.register),
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.success)
              .having((AuthState s) => s.action, 'action', AuthAction.register)
              .having(
                (AuthState s) => s.registerResult?.email,
                'register.email',
                'demo@example.com',
              )
              .having(
                (AuthState s) => s.registerResult?.otpTtlSeconds,
                'register.otpTtlSeconds',
                120,
              ),
        ]),
      );

      await cubit.register(
        username: 'demo',
        email: 'demo@example.com',
        password: 'password123',
        rePassword: 'password123',
        role: 'MUSICIAN',
      );
      await expectation;

      await cubit.close();
    });

    test('verify failure emits failure with verify action', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        verifyResponse: const Result<VerifyCodeResult>.failure(
          AppError(code: '400', message: 'Invalid code'),
        ),
      );
      final AuthCubit cubit = _createCubit(
        repository: repository,
        tokenStore: _InMemoryTokenStore(),
      );

      final Future<void> expectation = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.loading)
              .having((AuthState s) => s.action, 'action', AuthAction.verify),
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.failure)
              .having((AuthState s) => s.action, 'action', AuthAction.verify)
              .having(
                (AuthState s) => s.error?.message,
                'error.message',
                'Invalid code',
              ),
        ]),
      );

      await cubit.verifyCode(email: 'demo@example.com', code: '0000');
      await expectation;

      await cubit.close();
    });

    test('resend success emits success with resend payload', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        resendResponse: const Result<ResendCodeResult>.success(
          ResendCodeResult(
            otpTtlSeconds: 180,
            mailQueued: true,
            cooldownSeconds: 30,
          ),
        ),
      );
      final AuthCubit cubit = _createCubit(
        repository: repository,
        tokenStore: _InMemoryTokenStore(),
      );

      final Future<void> expectation = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.loading)
              .having((AuthState s) => s.action, 'action', AuthAction.resend),
          isA<AuthState>()
              .having((AuthState s) => s.status, 'status', AuthStatus.success)
              .having((AuthState s) => s.action, 'action', AuthAction.resend)
              .having(
                (AuthState s) => s.resendResult?.cooldownSeconds,
                'resend.cooldownSeconds',
                30,
              ),
        ]),
      );

      await cubit.resendCode(email: 'demo@example.com');
      await expectation;

      await cubit.close();
    });

    test(
      'forgot password normalizes username and preserves backend failure',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          requestPasswordResetResponse: const Result<void>.failure(
            AppError(
              code: '1109',
              message: 'Bu kullanıcı adıyla kayıtlı bir hesap bulunamadı.',
            ),
          ),
        );
        final AuthCubit cubit = _createCubit(
          repository: repository,
          tokenStore: _InMemoryTokenStore(),
        );

        final Future<void> expectation = expectLater(
          cubit.stream,
          emitsInOrder(<Matcher>[
            isA<AuthState>()
                .having((AuthState s) => s.status, 'status', AuthStatus.loading)
                .having(
                  (AuthState s) => s.action,
                  'action',
                  AuthAction.forgotPassword,
                ),
            isA<AuthState>()
                .having((AuthState s) => s.status, 'status', AuthStatus.failure)
                .having(
                  (AuthState s) => s.action,
                  'action',
                  AuthAction.forgotPassword,
                )
                .having(
                  (AuthState s) => s.error?.message,
                  'error.message',
                  'Bu kullanıcı adıyla kayıtlı bir hesap bulunamadı.',
                ),
          ]),
        );

        await cubit.requestPasswordReset(identifier: '  BeRkAy  ');
        await expectation;

        expect(repository.lastPasswordResetIdentifier, 'berkay');
        await cubit.close();
      },
    );
  });
}

AuthCubit _createCubit({
  required _FakeAuthRepository repository,
  required TokenStore tokenStore,
}) {
  return AuthCubit(
    loginUseCase: LoginUseCase(repository),
    registerUseCase: RegisterUseCase(repository),
    verifyCodeUseCase: VerifyCodeUseCase(repository),
    resendCodeUseCase: ResendCodeUseCase(repository),
    requestPasswordResetUseCase: RequestPasswordResetUseCase(repository),
    resetPasswordUseCase: ResetPasswordUseCase(repository),
    updateUsernameUseCase: UpdateUsernameUseCase(repository),
    tokenStore: tokenStore,
  );
}

class _InMemoryTokenStore implements TokenStore {
  String? token;
  int writeCount = 0;

  @override
  Future<void> clear() async {
    token = null;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async {
    writeCount += 1;
    this.token = token;
  }
}

class _FakeAuthRepository extends AuthRepository {
  String? lastPasswordResetIdentifier;

  _FakeAuthRepository({
    Result<LoginResult>? loginResponse,
    Result<RegisterResult>? registerResponse,
    Result<VerifyCodeResult>? verifyResponse,
    Result<ResendCodeResult>? resendResponse,
    Result<void>? requestPasswordResetResponse,
    Result<void>? resetPasswordResponse,
    Result<String>? updateUsernameResponse,
  }) : _loginResponse =
           loginResponse ??
           const Result<LoginResult>.success(LoginResult(token: 'ok')),
       _registerResponse =
           registerResponse ??
           const Result<RegisterResult>.success(
             RegisterResult(
               email: 'default@example.com',
               status: UserStatus.inactive,
               otpTtlSeconds: 90,
               mailQueued: true,
             ),
           ),
       _verifyResponse =
           verifyResponse ??
           const Result<VerifyCodeResult>.success(VerifyCodeResult()),
       _resendResponse =
           resendResponse ??
           const Result<ResendCodeResult>.success(
             ResendCodeResult(
               otpTtlSeconds: 90,
               mailQueued: true,
               cooldownSeconds: 20,
             ),
           ),
       _requestPasswordResetResponse =
           requestPasswordResetResponse ?? const Result<void>.success(null),
       _resetPasswordResponse =
           resetPasswordResponse ?? const Result<void>.success(null),
       _updateUsernameResponse =
           updateUsernameResponse ??
           const Result<String>.success('updated-username');

  final Result<LoginResult> _loginResponse;
  final Result<RegisterResult> _registerResponse;
  final Result<VerifyCodeResult> _verifyResponse;
  final Result<ResendCodeResult> _resendResponse;
  final Result<void> _requestPasswordResetResponse;
  final Result<void> _resetPasswordResponse;
  final Result<String> _updateUsernameResponse;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async => _loginResponse;

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
    String? studioName,
    String? studioAddress,
    String? studioPhone,
  }) async => _registerResponse;

  @override
  Future<Result<ResendCodeResult>> resendCode({required String email}) async =>
      _resendResponse;

  @override
  Future<Result<VerifyCodeResult>> verifyCode({
    required String email,
    required String code,
  }) async => _verifyResponse;

  @override
  Future<Result<void>> requestPasswordReset({
    required String identifier,
  }) async {
    lastPasswordResetIdentifier = identifier;
    return _requestPasswordResetResponse;
  }

  @override
  Future<Result<void>> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  }) async => _resetPasswordResponse;

  @override
  Future<Result<String>> updateUsername({required String username}) async =>
      _updateUsernameResponse;
}
