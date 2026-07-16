import 'user_status.dart';

class LoginResult {
  final String token;
  final UserStatus status;
  final String? userId;
  final String? username;
  final List<String> roles;
  final List<String> permissions;
  final bool isAdmin;

  const LoginResult({
    required this.token,
    this.status = UserStatus.active,
    this.userId,
    this.username,
    this.roles = const [],
    this.permissions = const [],
    this.isAdmin = false,
  });
}
