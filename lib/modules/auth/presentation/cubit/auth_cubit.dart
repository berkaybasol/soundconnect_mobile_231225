import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
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

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required VerifyCodeUseCase verifyCodeUseCase,
    required ResendCodeUseCase resendCodeUseCase,
    required TokenStore tokenStore,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _verifyCodeUseCase = verifyCodeUseCase,
        _resendCodeUseCase = resendCodeUseCase,
        _tokenStore = tokenStore,
        super(const AuthState.idle());

  Future<void> login({
    required String username,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, action: AuthAction.login));
    final result = await _loginUseCase(username: username, password: password);
    if (result.isSuccess && result.data != null) {
      await _tokenStore.writeToken(result.data!.token);
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.login,
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
    emit(state.copyWith(status: AuthStatus.loading, action: AuthAction.register));
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

  Future<void> verifyCode({
    required String email,
    required String code,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, action: AuthAction.verify));
    final result = await _verifyCodeUseCase(email: email, code: code);
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.verify,
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
    emit(state.copyWith(status: AuthStatus.loading, action: AuthAction.resend));
    final result = await _resendCodeUseCase(email: email);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AuthStatus.success,
          action: AuthAction.resend,
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
}
