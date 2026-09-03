class AuthSession {
  final String? token;
  final String? userId;
  final String? username;
  final String? accountStatus;
  final List<String> roles;
  final List<String> permissions;
  final DateTime? expiresAt;
  final bool isAdmin;
  final bool requiresListenerProfileChoice;

  const AuthSession._({
    required this.token,
    required this.userId,
    required this.username,
    required this.accountStatus,
    required this.roles,
    required this.permissions,
    required this.expiresAt,
    required this.isAdmin,
    required this.requiresListenerProfileChoice,
  });

  const AuthSession.guest()
    : this._(
        token: null,
        userId: null,
        username: null,
        accountStatus: null,
        roles: const [],
        permissions: const [],
        expiresAt: null,
        isAdmin: false,
        requiresListenerProfileChoice: false,
      );

  factory AuthSession.authenticated({
    required String token,
    required String? userId,
    required String? username,
    required String? accountStatus,
    required List<String> roles,
    required List<String> permissions,
    required DateTime expiresAt,
    required bool isAdmin,
    bool requiresListenerProfileChoice = false,
  }) {
    return AuthSession._(
      token: token,
      userId: userId,
      username: username,
      accountStatus: accountStatus,
      roles: List.unmodifiable(roles),
      permissions: List.unmodifiable(permissions),
      expiresAt: expiresAt,
      isAdmin: isAdmin,
      requiresListenerProfileChoice: requiresListenerProfileChoice,
    );
  }

  bool get isAuthenticated => token?.isNotEmpty == true;

  bool get isPendingVenue =>
      accountStatus?.trim().toUpperCase() == 'PENDING_VENUE_REQUEST';

  bool get isPendingStudio =>
      accountStatus?.trim().toUpperCase() == 'PENDING_STUDIO_REQUEST';

  bool get isRejectedStudio =>
      accountStatus?.trim().toUpperCase() == 'REJECTED_STUDIO_REQUEST';

  bool get isPendingBusiness => isPendingVenue || isPendingStudio;

  bool get isActive => accountStatus?.trim().toUpperCase() == 'ACTIVE';

  Set<String> get normalizedRoles => roles
      .map((role) => role.trim().toUpperCase())
      .where((role) => role.isNotEmpty)
      .toSet();

  bool hasAnyRole(Iterable<String> candidates) {
    final expected = candidates
        .map((role) => role.trim().toUpperCase())
        .toSet();
    return normalizedRoles.any(expected.contains);
  }
}
