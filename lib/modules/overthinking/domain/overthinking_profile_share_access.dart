import '../../../core/auth/auth_session.dart';

/// Mainstage also contains musicians; publication belongs to listeners only.
/// Profile visibility and the source post are additionally checked by the API.
bool canShareOverthinkingOnProfile(AuthSession? session) {
  if (session?.isAuthenticated != true ||
      session?.isActive != true ||
      session?.userId?.trim().isNotEmpty != true ||
      session!.isAdmin ||
      session.requiresListenerProfileChoice) {
    return false;
  }
  final roles = session.normalizedRoles
      .map((role) => role.startsWith('ROLE_') ? role.substring(5) : role)
      .toSet();
  return roles.contains('LISTENER') &&
      !roles.any(
        const {
          'ADMIN',
          'OWNER',
          'VENUE',
          'STUDIO',
          'BAND',
          'ORGANIZER',
          'PRODUCER',
          'MUSICIAN',
        }.contains,
      );
}
