import '../../core/auth/auth_session.dart';
import '../../core/policy/access_policy.dart';
import 'app_routes.dart';

class AppRouteGuard {
  static const Set<String> _anonymousRoutes = <String>{
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.otpVerify,
    AppRoutes.venueApplication,
    AppRoutes.venuePending,
  };

  static const Set<String> _publicProfileRoutes = <String>{
    AppRoutes.bandPublicProfile,
    AppRoutes.musicianPublicProfile,
    AppRoutes.venuePublicProfile,
    AppRoutes.studioPublicProfile,
  };

  static String? redirectFor(String? requestedRoute, AuthSession session) {
    final requested = requestedRoute ?? AppRoutes.login;
    final isPublic =
        _anonymousRoutes.contains(requested) ||
        _publicProfileRoutes.contains(requested);

    if (!session.isAuthenticated) {
      return isPublic ? null : AppRoutes.login;
    }

    if (session.isPendingVenue) {
      if (requested == AppRoutes.venuePending ||
          _publicProfileRoutes.contains(requested)) {
        return null;
      }
      return AppRoutes.venuePending;
    }

    if (!session.isActive) {
      return requested == AppRoutes.login ? null : AppRoutes.login;
    }

    if (_anonymousRoutes.contains(requested) ||
        requested == AppRoutes.venuePending) {
      return startRouteFor(session);
    }

    if (requested == AppRoutes.adminDashboard && !session.isAdmin) {
      return startRouteFor(session);
    }

    if (_musicianOwnerRoutes.contains(requested) &&
        !session.hasAnyRole(const ['ROLE_MUSICIAN', 'MUSICIAN'])) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.venueProfile &&
        !session.hasAnyRole(const ['ROLE_VENUE', 'VENUE'])) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.studioProfile &&
        !session.hasAnyRole(const ['ROLE_STUDIO', 'STUDIO'])) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.listenerProfile &&
        !session.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER'])) {
      return startRouteFor(session);
    }
    if (_backstageHomeRoutes.contains(requested) &&
        !AccessPolicy.canAccessBackstage(session.roles)) {
      return startRouteFor(session);
    }

    return null;
  }

  static String startRouteFor(AuthSession session) {
    if (!session.isAuthenticated) return AppRoutes.login;
    if (session.isPendingVenue) return AppRoutes.venuePending;
    if (session.isAdmin) return AppRoutes.adminDashboard;
    if (AccessPolicy.canAccessBackstage(session.roles)) {
      return AppRoutes.home;
    }
    if (session.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER'])) {
      return AppRoutes.listenerProfile;
    }
    return AppRoutes.login;
  }

  static const Set<String> _musicianOwnerRoutes = <String>{
    AppRoutes.musicianProfile,
    AppRoutes.myBands,
    AppRoutes.createBand,
    AppRoutes.bandProfile,
  };

  static const Set<String> _backstageHomeRoutes = <String>{
    AppRoutes.home,
    AppRoutes.backstageProfilesHome,
  };
}
