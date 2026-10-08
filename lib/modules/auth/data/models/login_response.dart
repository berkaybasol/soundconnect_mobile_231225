import '../../../../core/auth/jwt_claims.dart';
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
  final String? sessionScope;
  final String? applicationId;
  final bool requiresListenerProfileChoice;

  const LoginResponse({
    required this.token,
    required this.status,
    this.userId,
    this.username,
    this.roles = const [],
    this.permissions = const [],
    this.isAdmin = false,
    this.sessionScope,
    this.applicationId,
    required this.requiresListenerProfileChoice,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final requiresListenerProfileChoice = json['requiresListenerProfileChoice'];
    if (requiresListenerProfileChoice is! bool) {
      throw const FormatException(
        'requiresListenerProfileChoice must be a boolean',
      );
    }
    final claims = JwtClaims.tryParse(json['token'] as String?);
    final scope = json['sessionScope'];
    if (scope != null || claims?.sessionScope != null) {
      if (scope != 'VENUE_APPLICATION' ||
          claims?.sessionScope != scope ||
          json['applicationId'] != claims?.applicationId ||
          json['userId']?.toString() != claims?.subject ||
          _stringList(json['roles']).isNotEmpty ||
          _stringList(json['permissions']).isNotEmpty ||
          json['admin'] == true ||
          json['isAdmin'] == true ||
          requiresListenerProfileChoice) {
        throw const FormatException('Invalid application session');
      }
    }
    return LoginResponse(
      sessionScope: scope as String?,
      applicationId: json['applicationId'] as String?,
      token: json['token'] as String? ?? '',
      status: UserStatusParser.fromApi(json['status'] as String?),
      userId: json['userId']?.toString(),
      username: json['username']?.toString(),
      roles: _stringList(json['roles']),
      permissions: _stringList(json['permissions']),
      isAdmin: json['admin'] == true || json['isAdmin'] == true,
      requiresListenerProfileChoice: requiresListenerProfileChoice,
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
    sessionScope: sessionScope,
    applicationId: applicationId,
    requiresListenerProfileChoice: requiresListenerProfileChoice,
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
