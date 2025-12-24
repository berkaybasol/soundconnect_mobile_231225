import '../../domain/entities/login_result.dart';

class LoginResponse {
  final String token;

  const LoginResponse({required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(token: json['token'] as String? ?? '');
  }

  LoginResult toEntity() => LoginResult(token: token);
}
