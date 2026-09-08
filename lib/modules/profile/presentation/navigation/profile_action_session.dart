import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';

/// Binds a management surface to the account that opened it.
class ProfileActionSession {
  ProfileActionSession({required this.roles})
    : manager = serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null {
    session = manager?.session;
  }

  final List<String> roles;
  final AuthSessionManager? manager;
  late final AuthSession? session;

  String? get userId => session?.userId;

  bool get isCurrent {
    final entry = session;
    return entry != null &&
        identical(manager?.session, entry) &&
        entry.isAuthenticated &&
        entry.isActive &&
        (entry.userId?.trim().isNotEmpty ?? false) &&
        entry.hasAnyRole(roles);
  }
}
