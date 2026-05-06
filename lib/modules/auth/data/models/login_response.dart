import '../../domain/entities/login_result.dart';
import '../../domain/entities/user_status.dart';

class LoginResponse {
  final String token;
  final UserStatus status;

  const LoginResponse({required this.token, required this.status});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String? ?? '',
      status: UserStatusParser.fromApi(json['status'] as String?),
    );
  }

  LoginResult toEntity() => LoginResult(token: token, status: status);
}
