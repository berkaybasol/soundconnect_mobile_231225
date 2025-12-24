class AuthSession {
  final String? token;
  final List<String> roles;
  final List<String> permissions;

  const AuthSession({
    required this.token,
    required this.roles,
    required this.permissions,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;
}
