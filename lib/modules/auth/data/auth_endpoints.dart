class AuthEndpoints {
  static const String base = '/api/v1/auth';
  static const String register = '$base/register';
  static const String login = '$base/login';
  static const String verifyCode = '$base/verify-code';
  static const String resendCode = '$base/resend-code';
  static const String usernameAvailability = '$base/username-availability';
  static const String passwordResetAccount = '$base/password-reset/account';
  static const String forgotPassword = '$base/forgot-password';
  static const String resetPassword = '$base/reset-password';
  static const String googleSignIn = '$base/google-sign-in';
  static const String updateUsername = '/api/v1/users/me/username';
}
