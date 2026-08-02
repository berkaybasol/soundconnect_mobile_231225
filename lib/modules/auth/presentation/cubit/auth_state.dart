import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/entities/password_reset_account.dart';
import '../../domain/entities/register_result.dart';
import '../../domain/entities/resend_code_result.dart';
import '../../domain/entities/username_availability.dart';

enum AuthStatus { idle, loading, success, failure }

enum AuthAction {
  none,
  login,
  logout,
  register,
  verify,
  resend,
  usernameAvailability,
  passwordResetAccount,
  forgotPassword,
  resetPassword,
  updateUsername,
}

class AuthState {
  final AuthStatus status;
  final AuthAction action;
  final String? message;
  final AppError? error;
  final LoginResult? loginResult;
  final RegisterResult? registerResult;
  final ResendCodeResult? resendResult;
  final UsernameAvailability? usernameAvailability;
  final PasswordResetAccount? passwordResetAccount;

  const AuthState({
    required this.status,
    required this.action,
    this.message,
    this.error,
    this.loginResult,
    this.registerResult,
    this.resendResult,
    this.usernameAvailability,
    this.passwordResetAccount,
  });

  const AuthState.idle()
    : status = AuthStatus.idle,
      action = AuthAction.none,
      message = null,
      error = null,
      loginResult = null,
      registerResult = null,
      resendResult = null,
      usernameAvailability = null,
      passwordResetAccount = null;

  AuthState copyWith({
    AuthStatus? status,
    AuthAction? action,
    Object? message = copyWithUnset,
    Object? error = copyWithUnset,
    Object? loginResult = copyWithUnset,
    Object? registerResult = copyWithUnset,
    Object? resendResult = copyWithUnset,
    Object? usernameAvailability = copyWithUnset,
    Object? passwordResetAccount = copyWithUnset,
  }) {
    return AuthState(
      status: status ?? this.status,
      action: action ?? this.action,
      message: identical(message, copyWithUnset)
          ? this.message
          : message as String?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
      loginResult: identical(loginResult, copyWithUnset)
          ? this.loginResult
          : loginResult as LoginResult?,
      registerResult: identical(registerResult, copyWithUnset)
          ? this.registerResult
          : registerResult as RegisterResult?,
      resendResult: identical(resendResult, copyWithUnset)
          ? this.resendResult
          : resendResult as ResendCodeResult?,
      usernameAvailability: identical(usernameAvailability, copyWithUnset)
          ? this.usernameAvailability
          : usernameAvailability as UsernameAvailability?,
      passwordResetAccount: identical(passwordResetAccount, copyWithUnset)
          ? this.passwordResetAccount
          : passwordResetAccount as PasswordResetAccount?,
    );
  }
}
