import '../../../../core/error/app_error.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/entities/register_result.dart';
import '../../domain/entities/resend_code_result.dart';

enum AuthStatus { idle, loading, success, failure }

enum AuthAction { none, login, register, verify, resend }

class AuthState {
  final AuthStatus status;
  final AuthAction action;
  final String? message;
  final AppError? error;
  final LoginResult? loginResult;
  final RegisterResult? registerResult;
  final ResendCodeResult? resendResult;

  const AuthState({
    required this.status,
    required this.action,
    this.message,
    this.error,
    this.loginResult,
    this.registerResult,
    this.resendResult,
  });

  const AuthState.idle()
      : status = AuthStatus.idle,
        action = AuthAction.none,
        message = null,
        error = null,
        loginResult = null,
        registerResult = null,
        resendResult = null;

  AuthState copyWith({
    AuthStatus? status,
    AuthAction? action,
    String? message,
    AppError? error,
    LoginResult? loginResult,
    RegisterResult? registerResult,
    ResendCodeResult? resendResult,
  }) {
    return AuthState(
      status: status ?? this.status,
      action: action ?? this.action,
      message: message ?? this.message,
      error: error ?? this.error,
      loginResult: loginResult ?? this.loginResult,
      registerResult: registerResult ?? this.registerResult,
      resendResult: resendResult ?? this.resendResult,
    );
  }
}
