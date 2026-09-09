import '../auth/auth_session.dart';
import 'access_policy.dart';

enum StageMode { mainstage, backstage }

class StageModeResolver {
  static StageMode fromRoles(List<String> roles) {
    return AccessPolicy.canAccessBackstage(roles)
        ? StageMode.backstage
        : StageMode.mainstage;
  }

  /// Route arguments describe a preferred layout, never the viewer's role.
  /// Unknown/guest/listener sessions must not inherit a public profile's
  /// backstage default, even for direct routes or late account replacements.
  static StageMode forViewer(
    AuthSession? session, {
    required StageMode requested,
  }) {
    if (requested == StageMode.mainstage ||
        session == null ||
        !session.isAuthenticated ||
        !session.isActive) {
      return StageMode.mainstage;
    }
    return fromRoles(session.roles);
  }
}
