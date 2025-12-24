import '../../domain/entities/register_result.dart';
import '../../domain/entities/user_status.dart';

class RegisterResponse {
  final String email;
  final String status;
  final int otpTtlSeconds;
  final bool mailQueued;

  const RegisterResponse({
    required this.email,
    required this.status,
    required this.otpTtlSeconds,
    required this.mailQueued,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? 'INACTIVE',
      otpTtlSeconds: (json['otpTtlSeconds'] as num?)?.toInt() ?? 0,
      mailQueued: json['mailQueued'] as bool? ?? false,
    );
  }

  RegisterResult toEntity() {
    return RegisterResult(
      email: email,
      status: UserStatusParser.fromApi(status),
      otpTtlSeconds: otpTtlSeconds,
      mailQueued: mailQueued,
    );
  }
}
