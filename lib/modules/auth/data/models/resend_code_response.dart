import '../../domain/entities/resend_code_result.dart';

class ResendCodeResponse {
  final int otpTtlSeconds;
  final bool mailQueued;
  final int cooldownSeconds;

  const ResendCodeResponse({
    required this.otpTtlSeconds,
    required this.mailQueued,
    required this.cooldownSeconds,
  });

  factory ResendCodeResponse.fromJson(Map<String, dynamic> json) {
    return ResendCodeResponse(
      otpTtlSeconds: (json['otpTtlSeconds'] as num?)?.toInt() ?? 0,
      mailQueued: json['mailQueued'] as bool? ?? false,
      cooldownSeconds: (json['cooldownSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  ResendCodeResult toEntity() {
    return ResendCodeResult(
      otpTtlSeconds: otpTtlSeconds,
      mailQueued: mailQueued,
      cooldownSeconds: cooldownSeconds,
    );
  }
}
