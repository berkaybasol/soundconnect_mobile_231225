import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/error/app_error.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/entities/verify_code_result.dart';
import '../../domain/entities/password_reset_account.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/username_policy.dart';
import '../../domain/usecases/check_username_availability_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/resolve_password_reset_account_usecase.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/resend_code_usecase.dart';
import '../../domain/usecases/update_username_usecase.dart';
import '../../domain/usecases/verify_code_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final VerifyCodeUseCase _verifyCodeUseCase;
  final ResendCodeUseCase _resendCodeUseCase;
  final RequestPasswordResetUseCase _requestPasswordResetUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final UpdateUsernameUseCase _updateUsernameUseCase;
  final CheckUsernameAvailabilityUseCase? _checkUsernameAvailabilityUseCase;
  final ResolvePasswordResetAccountUseCase? _resolvePasswordResetAccountUseCase;
  final TokenStore _tokenStore;
  final AuthSessionManager? _sessionManager;
  bool _wasSessionAuthenticated;
  Future<void>? _loginInFlight;
  Future<void>? _logoutInFlight;
  Future<void>? _registerInFlight;
  Future<void>? _otpActionInFlight;
  int _usernameAvailabilityRequest = 0;
  int _passwordResetAccountRequest = 0;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required VerifyCodeUseCase verifyCodeUseCase,
    required ResendCodeUseCase resendCodeUseCase,
    required RequestPasswordResetUseCase requestPasswordResetUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required UpdateUsernameUseCase updateUsernameUseCase,
    CheckUsernameAvailabilityUseCase? checkUsernameAvailabilityUseCase,
    ResolvePasswordResetAccountUseCase? resolvePasswordResetAccountUseCase,
    required TokenStore tokenStore,
    AuthSessionManager? sessionManager,
  }) : _loginUseCase = loginUseCase,
       _registerUseCase = registerUseCase,
       _verifyCodeUseCase = verifyCodeUseCase,
       _resendCodeUseCase = resendCodeUseCase,
       _requestPasswordResetUseCase = requestPasswordResetUseCase,
       _resetPasswordUseCase = resetPasswordUseCase,
       _updateUsernameUseCase = updateUsernameUseCase,
       _checkUsernameAvailabilityUseCase = checkUsernameAvailabilityUseCase,
       _resolvePasswordResetAccountUseCase = resolvePasswordResetAccountUseCase,
       _tokenStore = tokenStore,
       _sessionManager = sessionManager,
       _wasSessionAuthenticated =
           sessionManager?.session.isAuthenticated ?? false,
       super(const AuthState.idle()) {
    _sessionManager?.addListener(_handleSessionChanged);
  }

  Future<void> login({required String username, required String password}) {
    final inFlight = _loginInFlight;
    if (inFlight != null) return inFlight;

    final operation = _performLogin(username: username, password: password);
    _loginInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_loginInFlight, operation)) _loginInFlight = null;
    });
  }

  Future<void> _performLogin({
    required String username,
    required String password,
  }) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.login,
        error: null,
      ),
    );
    final result = await _loginUseCase(username: username, password: password);
    if (result.isSuccess && result.data != null) {
      final loginResult = result.data!;
      final persistenceError = await _persistSession(loginResult);
      if (persistenceError != null) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            action: AuthAction.login,
            error: persistenceError,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.login,
          error: null,
          loginResult: result.data,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.login,
        error: result.error,
      ),
    );
  }

  Future<void> logout() {
    final inFlight = _logoutInFlight;
    if (inFlight != null) return inFlight;

    final sessionManager = _sessionManager;
    if (_isLoggedOut &&
        (sessionManager == null || !sessionManager.session.isAuthenticated)) {
      return Future<void>.value();
    }

    final operation = _performLogout();
    _logoutInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_logoutInFlight, operation)) _logoutInFlight = null;
    });
  }

  Future<void> _performLogout() async {
    final sessionManager = _sessionManager;
    if (sessionManager != null) {
      await sessionManager.logout();
    } else {
      await _tokenStore.clear();
    }
    _emitLoggedOut();
  }

  void _handleSessionChanged() {
    final sessionManager = _sessionManager;
    if (sessionManager == null) return;

    final isAuthenticated = sessionManager.session.isAuthenticated;
    final didEndSession = _wasSessionAuthenticated && !isAuthenticated;
    _wasSessionAuthenticated = isAuthenticated;

    if (didEndSession) _emitLoggedOut();
  }

  bool get _isLoggedOut =>
      state.status == AuthStatus.success &&
      state.action == AuthAction.logout &&
      state.message == null &&
      state.error == null &&
      state.loginResult == null &&
      state.registerResult == null &&
      state.resendResult == null;

  void _emitLoggedOut() {
    if (isClosed || _isLoggedOut) return;
    emit(
      const AuthState(status: AuthStatus.success, action: AuthAction.logout),
    );
  }

  Future<void> register({
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
  }) {
    final inFlight = _registerInFlight;
    if (inFlight != null) return inFlight;

    final operation = _performRegister(
      username: username,
      email: email,
      password: password,
      rePassword: rePassword,
      role: role,
      venueName: venueName,
      venueAddress: venueAddress,
      phone: phone,
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
      studioName: studioName,
      studioAddress: studioAddress,
      studioPhone: studioPhone,
    );
    _registerInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_registerInFlight, operation)) _registerInFlight = null;
    });
  }

  Future<void> _performRegister({
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
  }) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.register,
        error: null,
      ),
    );
    final result = await _registerUseCase(
      username: username,
      email: email,
      password: password,
      rePassword: rePassword,
      role: role,
      venueName: venueName,
      venueAddress: venueAddress,
      phone: phone,
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
      studioName: studioName,
      studioAddress: studioAddress,
      studioPhone: studioPhone,
    );
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.register,
          error: null,
          registerResult: result.data,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.register,
        error: result.error,
      ),
    );
  }

  Future<void> verifyCode({required String email, required String code}) {
    final inFlight = _otpActionInFlight;
    if (inFlight != null) return inFlight;

    final operation = _performVerifyCode(email: email, code: code);
    _otpActionInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_otpActionInFlight, operation)) _otpActionInFlight = null;
    });
  }

  Future<void> _performVerifyCode({
    required String email,
    required String code,
  }) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.verify,
        error: null,
        loginResult: null,
      ),
    );
    final result = await _verifyCodeUseCase(email: email, code: code);
    if (result.isSuccess) {
      final verification = result.data ?? const VerifyCodeResult();
      final listenerSession = verification.listenerSession;
      if (listenerSession != null &&
          !verification.requiresListenerProfileChoice) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            action: AuthAction.verify,
            error: const AppError(
              code: 'auth_verify_unexpected_session',
              message: 'Doğrulama oturumu güvenli biçimde başlatılamadı.',
            ),
            loginResult: null,
          ),
        );
        return;
      }
      if (listenerSession != null) {
        final persistenceError = await _persistSession(listenerSession);
        if (persistenceError != null) {
          emit(
            state.copyWith(
              status: AuthStatus.failure,
              action: AuthAction.verify,
              error: persistenceError,
              loginResult: null,
            ),
          );
          return;
        }
      }
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.verify,
          error: null,
          loginResult: listenerSession,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.verify,
        error: result.error,
      ),
    );
  }

  Future<AppError?> _persistSession(LoginResult loginResult) async {
    try {
      final sessionManager = _sessionManager;
      if (sessionManager != null) {
        await sessionManager.startSession(
          token: loginResult.token,
          username: loginResult.username,
          accountStatus: loginResult.status.apiValue,
          requiresListenerProfileChoice:
              loginResult.requiresListenerProfileChoice,
        );
      } else {
        await _tokenStore.writeToken(loginResult.token);
      }
      return null;
    } catch (_) {
      return const AppError(
        code: 'auth_session_persist_failed',
        message: 'Oturum güvenli şekilde başlatılamadı. Tekrar giriş yap.',
      );
    }
  }

  Future<void> resendCode({required String email}) {
    final inFlight = _otpActionInFlight;
    if (inFlight != null) return inFlight;

    final operation = _performResendCode(email: email);
    _otpActionInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_otpActionInFlight, operation)) _otpActionInFlight = null;
    });
  }

  Future<void> _performResendCode({required String email}) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.resend,
        error: null,
      ),
    );
    final result = await _resendCodeUseCase(email: email);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.resend,
          error: null,
          resendResult: result.data,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.resend,
        error: result.error,
      ),
    );
  }

  Future<UsernameAvailability?> checkUsernameAvailability({
    required String username,
  }) async {
    final requestId = ++_usernameAvailabilityRequest;
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.usernameAvailability,
        error: null,
        usernameAvailability: null,
      ),
    );
    final useCase = _checkUsernameAvailabilityUseCase;
    if (useCase == null) {
      if (requestId == _usernameAvailabilityRequest) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            action: AuthAction.usernameAvailability,
            error: const AppError(
              code: 'auth_username_availability_unavailable',
              message: 'Kullanıcı adı şu anda kontrol edilemiyor.',
            ),
          ),
        );
      }
      return null;
    }

    final result = await useCase(username: username);
    if (requestId != _usernameAvailabilityRequest || isClosed) return null;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.usernameAvailability,
          error: null,
          usernameAvailability: result.data,
        ),
      );
      return result.data;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.usernameAvailability,
        error: result.error,
        usernameAvailability: null,
      ),
    );
    return null;
  }

  Future<PasswordResetAccount?> resolvePasswordResetAccount({
    required String identifier,
  }) async {
    final requestId = ++_passwordResetAccountRequest;
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.passwordResetAccount,
        message: null,
        error: null,
        passwordResetAccount: null,
      ),
    );
    final useCase = _resolvePasswordResetAccountUseCase;
    if (useCase == null) {
      if (requestId == _passwordResetAccountRequest) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            action: AuthAction.passwordResetAccount,
            error: const AppError(
              code: 'auth_password_reset_account_unavailable',
              message: 'Hesap şu anda kontrol edilemiyor. Lütfen tekrar dene.',
            ),
          ),
        );
      }
      return null;
    }

    final result = await useCase(identifier: identifier);
    if (requestId != _passwordResetAccountRequest || isClosed) return null;
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.passwordResetAccount,
          error: null,
          passwordResetAccount: result.data,
        ),
      );
      return result.data;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.passwordResetAccount,
        error: result.error,
        passwordResetAccount: null,
      ),
    );
    return null;
  }

  Future<void> requestPasswordReset({required String identifier}) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.forgotPassword,
        message: null,
        error: null,
      ),
    );
    final result = await _requestPasswordResetUseCase(identifier: identifier);
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.forgotPassword,
          message: 'Şifre sıfırlama kodu gönderildi.',
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.forgotPassword,
        message: null,
        error: result.error,
      ),
    );
  }

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  }) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.resetPassword,
        message: null,
        error: null,
      ),
    );
    final result = await _resetPasswordUseCase(
      identifier: identifier,
      code: code,
      password: password,
      rePassword: rePassword,
    );
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.resetPassword,
          message: 'Şifren güncellendi. Yeni şifrenle giriş yapabilirsin.',
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.resetPassword,
        message: null,
        error: result.error,
      ),
    );
  }

  Future<void> updateUsername({required String username}) async {
    final sessionManager = _sessionManager;
    final expectedUserId = sessionManager?.session.userId?.trim();
    final expectedToken = sessionManager?.session.token?.trim();
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.updateUsername,
        message: null,
        error: null,
      ),
    );
    final result = await _updateUsernameUseCase(username: username);
    if (sessionManager != null &&
        (sessionManager.session.userId?.trim() != expectedUserId ||
            sessionManager.session.token?.trim() != expectedToken)) {
      return;
    }
    final backendUsername = result.data;
    final canonicalUsername = backendUsername == null
        ? null
        : UsernamePolicy.normalize(backendUsername);
    if (result.isSuccess &&
        backendUsername != null &&
        canonicalUsername != null &&
        UsernamePolicy.isValid(canonicalUsername)) {
      try {
        final didUpdate = await sessionManager?.updateUsername(
          backendUsername,
          expectedUserId: expectedUserId,
          expectedToken: expectedToken,
        );
        if (didUpdate == false) return;
      } catch (_) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            action: AuthAction.updateUsername,
            message: null,
            error: const AppError(
              code: 'auth_username_session_update_failed',
              message:
                  'Kullanıcı adı güncellendi ancak oturum bilgisi yenilenemedi. '
                  'Lütfen yeniden giriş yap.',
            ),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.updateUsername,
          message: canonicalUsername,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        action: AuthAction.updateUsername,
        message: null,
        error:
            result.error ??
            const AppError(
              code: 'auth_update_username_invalid_response',
              message: 'Kullanıcı adı güncellenemedi. Lütfen tekrar dene.',
            ),
      ),
    );
  }

  @override
  Future<void> close() {
    _sessionManager?.removeListener(_handleSessionChanged);
    return super.close();
  }
}
