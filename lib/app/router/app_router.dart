import 'package:flutter/material.dart';
import '../../core/auth/auth_session_manager.dart';
import '../../core/di/service_locator.dart';
import '../../core/policy/stage_mode.dart';
import '../../modules/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../modules/auth/presentation/screens/account_settings_screen.dart';
import '../../modules/auth/presentation/screens/forgot_password_screen.dart';
import '../../modules/auth/presentation/screens/login_screen.dart';
import '../../modules/auth/presentation/screens/register_screen.dart';
import '../../modules/auth/presentation/screens/otp_verify_screen.dart';
import '../../modules/auth/presentation/screens/venue_application_screen.dart';
import '../../modules/auth/presentation/screens/venue_pending_screen.dart';
import '../../modules/collab/presentation/collab_route_args.dart';
import '../../modules/collab/presentation/screens/collab_discovery_screen.dart';
import '../../modules/collab/presentation/theme/collab_visual_theme.dart';
import '../../modules/dm/presentation/screens/dm_chat_screen.dart';
import '../../modules/dm/presentation/screens/dm_conversations_screen.dart';
import '../../modules/notification/presentation/screens/notification_screen.dart';
import '../../modules/profile/presentation/screens/musician_profile_screen.dart';
import '../../modules/profile/presentation/screens/musician_public_profile_screen.dart';
import '../../modules/profile/presentation/screens/create_band_screen.dart';
import '../../modules/profile/presentation/screens/backstage_profiles_home_screen.dart';
import '../../modules/profile/presentation/screens/band_profile_screen.dart';
import '../../modules/profile/presentation/screens/my_bands_screen.dart';
import '../../modules/profile/presentation/screens/listener_profile_screen.dart';
import '../../modules/profile/presentation/screens/venue_profile_screen.dart';
import '../../modules/profile/presentation/screens/venue_public_profile_screen.dart';
import '../../modules/profile/presentation/screens/studio_profile_screen.dart';
import '../../modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../modules/tablegroup/presentation/screens/table_group_create_screen.dart';
import '../../modules/tablegroup/presentation/screens/table_group_list_screen.dart';
import '../../modules/tablegroup/presentation/screens/table_group_route_args.dart';
import '../../modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'app_routes.dart';
import 'app_route_guard.dart';

class AppRouter {
  static T? _arguments<T>(RouteSettings settings) {
    final value = settings.arguments;
    return value is T ? value : null;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final session = serviceLocator<AuthSessionManager>().session;
    final redirect = AppRouteGuard.redirectFor(settings.name, session);
    if (redirect != null && redirect != settings.name) {
      return onGenerateRoute(RouteSettings(name: redirect));
    }

    switch (settings.name) {
      case AppRoutes.adminDashboard:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AdminDashboardScreen(),
        );
      case AppRoutes.login:
        final args = _arguments<LoginRouteArgs>(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginScreen(initialNotice: args?.initialNotice),
        );
      case AppRoutes.register:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RegisterScreen(),
        );
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ForgotPasswordScreen(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AccountSettingsScreen(),
        );
      case AppRoutes.accountSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AccountSettingsScreen(),
        );
      case AppRoutes.otpVerify:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OtpVerifyScreen(),
        );
      case AppRoutes.venueApplication:
        final args = _arguments<VenueApplicationArgs>(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenueApplicationScreen(args: args),
        );
      case AppRoutes.venuePending:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenuePendingScreen(),
        );
      case AppRoutes.studioPending:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              VenuePendingScreen(membershipType: PendingMembershipType.studio),
        );
      case AppRoutes.studioRejected:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenuePendingScreen(
            membershipType: PendingMembershipType.studioRejected,
          ),
        );
      case AppRoutes.musicianProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => MusicianProfileScreen(),
        );
      case AppRoutes.myBands:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => MyBandsScreen(),
        );
      case AppRoutes.createBand:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CreateBandScreen(),
        );
      case AppRoutes.bandProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BandProfileScreen(),
        );
      case AppRoutes.bandMemberProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BandProfileScreen(),
        );
      case AppRoutes.bandPublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BandProfileScreen(),
        );
      case AppRoutes.musicianPublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => MusicianPublicProfileScreen(),
        );
      case AppRoutes.venueProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenueProfileScreen(),
        );
      case AppRoutes.venuePublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenuePublicProfileScreen(),
        );
      case AppRoutes.studioProfile:
        final args = settings.arguments is StudioProfileScreenArgs
            ? settings.arguments! as StudioProfileScreenArgs
            : const StudioProfileScreenArgs();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              StudioProfileScreen(openContactEditor: args.openContactEditor),
        );
      case AppRoutes.studioPublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudioPublicProfileScreen(),
        );
      case AppRoutes.studioReservationCalendar:
        final args = _arguments<StudioReservationCalendarArgs>(settings);
        final hasValidArguments =
            args != null &&
            args.roomId.trim().isNotEmpty &&
            args.studioProfileId.trim().isNotEmpty;
        final canOpenOwnerCalendar =
            args?.ownerMode != true ||
            AppRouteGuard.canOpenStudioOwnerReservationCalendar(session);
        if (!hasValidArguments || !canOpenOwnerCalendar) {
          return onGenerateRoute(
            RouteSettings(name: AppRouteGuard.startRouteFor(session)),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => StudioReservationCalendarScreen(args: args),
        );
      case AppRoutes.listenerProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ListenerProfileScreen(),
        );
      case AppRoutes.overthinkingFeed:
        final args = _arguments<OverthinkingFeedArgs>(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OverthinkingFeedScreen(
            bottomBarStageMode: args?.bottomBarStageMode ?? StageMode.mainstage,
          ),
        );
      case AppRoutes.notifications:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const NotificationScreen(),
        );
      case AppRoutes.tableGroupList:
        final args = _arguments<TableGroupListArgs>(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              TableGroupListScreen(args: args ?? const TableGroupListArgs()),
        );
      case AppRoutes.tableGroupCreate:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TableGroupCreateScreen(),
        );
      case AppRoutes.tableGroupDetail:
        final args = _arguments<TableGroupDetailArgs>(settings);
        if (args == null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TableGroupListScreen(),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TableGroupDetailScreen(args: args),
        );
      case AppRoutes.dmConversations:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DmConversationsScreen(),
        );
      case AppRoutes.dmChat:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DmChatScreen(),
        );
      case AppRoutes.backstageProfilesHome:
        final args = _arguments<BackstageProfilesHomeArgs>(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BackstageProfilesHomeScreen(
            profileImageUrl: args?.profileImageUrl,
          ),
        );
      case AppRoutes.collabDiscovery:
        final args = _arguments<CollabDiscoveryRouteArgs>(settings);
        return collabPageRoute(
          settings: settings,
          builder: (_) =>
              CollabDiscoveryScreen(initialListingId: args?.initialListingId),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BackstageProfilesHomeScreen(),
        );
      default:
        final fallback = AppRouteGuard.startRouteFor(session);
        if (fallback != settings.name) {
          return onGenerateRoute(RouteSettings(name: fallback));
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginScreen(),
        );
    }
  }
}
