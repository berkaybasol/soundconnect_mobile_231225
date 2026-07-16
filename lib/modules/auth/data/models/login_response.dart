import '../../domain/entities/login_result.dart';
import '../../domain/entities/user_status.dart';

class LoginResponse {
  final String token;
  final UserStatus status;
  final String? userId;
  final String? username;
  final List<String> roles;
  final List<String> permissions;
  final bool isAdmin;

  const LoginResponse({
    required this.token,
    required this.status,
    this.userId,
    this.username,
    this.roles = const [],
    this.permissions = const [],
    this.isAdmin = false,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String? ?? '',
      status: UserStatusParser.fromApi(json['status'] as String?),
      userId: json['userId']?.toString(),
      username: json['username']?.toString(),
      roles: _stringList(json['roles']),
      permissions: _stringList(json['permissions']),
      isAdmin: json['admin'] == true || json['isAdmin'] == true,
    );
  }

  LoginResult toEntity() => LoginResult(
    token: token,
    status: status,
    userId: userId,
    username: username,
    roles: roles,
    permissions: permissions,
    isAdmin: isAdmin,
  );

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
