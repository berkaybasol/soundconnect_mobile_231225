import '../auth/auth_session.dart';
import '../policy/access_policy.dart';

enum AppDeepLinkAccess { requestAuthentication, openCollab, unavailable }

AppDeepLinkAccess resolveAppDeepLinkAccess(AuthSession session) {
  if (!session.isAuthenticated) {
    return AppDeepLinkAccess.requestAuthentication;
  }
  if (session.isActive && AccessPolicy.canAccessCollab(session.roles)) {
    return AppDeepLinkAccess.openCollab;
  }
  return AppDeepLinkAccess.unavailable;
}
