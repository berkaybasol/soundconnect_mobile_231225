import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/error/app_error.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/resend_code_usecase.dart';
import '../../domain/usecases/verify_code_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final VerifyCodeUseCase _verifyCodeUseCase;
  final ResendCodeUseCase _resendCodeUseCase;
  final TokenStore _tokenStore;
  final AuthSessionManager? _sessionManager;
  bool _wasSessionAuthenticated;
  Future<void>? _logoutInFlight;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required VerifyCodeUseCase verifyCodeUseCase,
    required ResendCodeUseCase resendCodeUseCase,
    required TokenStore tokenStore,
    AuthSessionManager? sessionManager,
  }) : _loginUseCase = loginUseCase,
       _registerUseCase = registerUseCase,
       _verifyCodeUseCase = verifyCodeUseCase,
       _resendCodeUseCase = resendCodeUseCase,
       _tokenStore = tokenStore,
       _sessionManager = sessionManager,
       _wasSessionAuthenticated =
           sessionManager?.session.isAuthenticated ?? false,
       super(const AuthState.idle()) {
    _sessionManager?.addListener(_handleSessionChanged);
  }

  Future<void> login({
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
      try {
        final sessionManager = _sessionManager;
        if (sessionManager != null) {
          await sessionManager.startSession(
            token: loginResult.token,
            username: loginResult.username,
            accountStatus: loginResult.status.apiValue,
          );
        } else {
          await _tokenStore.writeToken(loginResult.token);
        }
      } catch (_) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            action: AuthAction.login,
            error: const AppError(
              code: 'auth_session_persist_failed',
              message: 'Oturum guvenli sekilde baslatilamadi. Tekrar dene.',
            ),
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

  Future<void> verifyCode({required String email, required String code}) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        action: AuthAction.verify,
        error: null,
      ),
    );
    final result = await _verifyCodeUseCase(email: email, code: code);
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.verify,
          error: null,
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

  Future<void> resendCode({required String email}) async {
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

  @override
  Future<void> close() {
    _sessionManager?.removeListener(_handleSessionChanged);
    return super.close();
  }
}
