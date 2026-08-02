import 'user_status.dart';

class RegisterResult {
  final String email;
  final UserStatus status;
  final int otpTtlSeconds;
  final bool mailQueued;
  final String? applicationId;

  const RegisterResult({
    required this.email,
    required this.status,
    required this.otpTtlSeconds,
    required this.mailQueued,
    this.applicationId,
  });
}
