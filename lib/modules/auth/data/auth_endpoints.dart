class AuthEndpoints {
  static const String base = '/api/v1/auth';
  static const String register = '$base/register';
  static const String login = '$base/login';
  static const String verifyCode = '$base/verify-code';
  static const String resendCode = '$base/resend-code';
  static const String googleSignIn = '$base/google-sign-in';
}
