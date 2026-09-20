import '../../core/auth/auth_session.dart';
import '../../core/policy/access_policy.dart';
import '../../core/policy/profile_feed_availability.dart';
import '../../modules/admin/domain/musician_feed_report_admin.dart';
import '../../modules/admin/domain/marketplace_report_admin.dart';
import '../../modules/musician_feed/domain/backstage_feed_session.dart';
import '../../modules/promotion/domain/announcement_access.dart';
import 'app_routes.dart';

class AppRouteGuard {
  static const Set<String> _anonymousRoutes = <String>{
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.otpVerify,
    AppRoutes.venueApplication,
    AppRoutes.venuePending,
    AppRoutes.studioPending,
    AppRoutes.studioRejected,
  };

  static const Set<String> _publicProfileRoutes = <String>{
    AppRoutes.bandPublicProfile,
    AppRoutes.musicianPublicProfile,
    AppRoutes.venuePublicProfile,
    AppRoutes.studioPublicProfile,
  };

  /// Routes that belong to sign-in, registration, recovery or account
  /// activation. A pending app link must survive navigation inside this flow.
  static bool isAnonymousFlowRoute(String? routeName) =>
      routeName != null && _anonymousRoutes.contains(routeName);

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

    if (session.isPendingStudio) {
      if (requested == AppRoutes.studioPending ||
          _publicProfileRoutes.contains(requested)) {
        return null;
      }
      return AppRoutes.studioPending;
    }

    if (session.isRejectedStudio) {
      if (requested == AppRoutes.studioRejected ||
          _publicProfileRoutes.contains(requested)) {
        return null;
      }
      return AppRoutes.studioRejected;
    }

    if (!session.isActive) {
      return requested == AppRoutes.login ? null : AppRoutes.login;
    }

    final isListener = session.hasAnyRole(const <String>[
      'ROLE_LISTENER',
      'LISTENER',
    ]);
    if (isListener && session.requiresListenerProfileChoice) {
      return requested == AppRoutes.listenerProfileChoice
          ? null
          : AppRoutes.listenerProfileChoice;
    }
    if (isListener && requested == AppRoutes.listenerProfileChoice) {
      return AppRoutes.listenerProfile;
    }
    if (!ProfileFeedAvailability.enabled &&
        const {
          AppRoutes.backstageProfilesHome,
          AppRoutes.listenerFeed,
          AppRoutes.musicianFeedMutedAuthors,
        }.contains(requested)) {
      return startRouteFor(session);
    }
    if (isListener &&
        const {
          AppRoutes.studioProfile,
          AppRoutes.studioPublicProfile,
          AppRoutes.studioReservationCalendar,
        }.contains(requested)) {
      return AppRoutes.studioListenerInfo;
    }
    if (isListener && requested == AppRoutes.collabDiscovery) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.marketplace &&
        !AccessPolicy.canAccessMarketplace(session.roles)) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.listenerFeed &&
        backstageFeedSessionIdentity(session)?.audience !=
            BackstageFeedAudience.listener) {
      return startRouteFor(session);
    }

    if (_anonymousRoutes.contains(requested) ||
        requested == AppRoutes.venuePending ||
        requested == AppRoutes.studioPending ||
        requested == AppRoutes.studioRejected) {
      return startRouteFor(session);
    }

    if (requested == AppRoutes.adminDashboard && !session.isAdmin) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.adminAnnouncements &&
        announcementSessionIdentity(session, admin: true) == null) {
      return startRouteFor(session);
    }

    if (requested == AppRoutes.adminMusicianFeedReports &&
        !canManageMusicianFeedReports(session)) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.adminMarketplaceReports &&
        !canManageMarketplaceReports(session)) {
      return startRouteFor(session);
    }

    if (requested == AppRoutes.musicianFeedMutedAuthors &&
        backstageFeedSessionIdentity(session) == null) {
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
    if ((requested == AppRoutes.listenerProfile ||
            requested == AppRoutes.listenerProfileChoice) &&
        !session.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER'])) {
      return startRouteFor(session);
    }
    if (_backstageRoutes.contains(requested) &&
        !AccessPolicy.canAccessBackstage(session.roles)) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.collabDiscovery &&
        !AccessPolicy.canAccessCollab(session.roles)) {
      return startRouteFor(session);
    }
    if (requested == AppRoutes.tableGroupCreate &&
        !AccessPolicy.canCreateOrJoinTableGroups(session.roles)) {
      return AppRoutes.tableGroupList;
    }

    return null;
  }

  static String startRouteFor(AuthSession session) {
    if (!session.isAuthenticated) return AppRoutes.login;
    if (session.isPendingVenue) return AppRoutes.venuePending;
    if (session.isPendingStudio) return AppRoutes.studioPending;
    if (session.isRejectedStudio) return AppRoutes.studioRejected;
    if (session.isAdmin) return AppRoutes.adminDashboard;
    if (AccessPolicy.canAccessBackstage(session.roles)) {
      return AppRoutes.home;
    }
    if (session.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER'])) {
      return session.requiresListenerProfileChoice
          ? AppRoutes.listenerProfileChoice
          : AppRoutes.listenerProfile;
    }
    return AppRoutes.login;
  }

  static bool canOpenStudioOwnerReservationCalendar(AuthSession session) =>
      session.isAuthenticated &&
      session.isActive &&
      session.hasAnyRole(const ['ROLE_STUDIO', 'STUDIO']);

  static const Set<String> _musicianOwnerRoutes = <String>{
    AppRoutes.musicianProfile,
    AppRoutes.myBands,
    AppRoutes.createBand,
    AppRoutes.bandProfile,
  };

  static const Set<String> _backstageRoutes = <String>{
    AppRoutes.home,
    AppRoutes.backstageProfilesHome,
  };
}
