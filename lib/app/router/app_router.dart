import 'package:flutter/material.dart';
import '../../core/policy/stage_mode.dart';
import '../../modules/auth/presentation/screens/login_screen.dart';
import '../../modules/auth/presentation/screens/register_screen.dart';
import '../../modules/auth/presentation/screens/otp_verify_screen.dart';
import '../../modules/auth/presentation/screens/venue_application_screen.dart';
import '../../modules/auth/presentation/screens/venue_pending_screen.dart';
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

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginScreen(),
        );
      case AppRoutes.register:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RegisterScreen(),
        );
      case AppRoutes.otpVerify:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OtpVerifyScreen(),
        );
      case AppRoutes.venueApplication:
        final args = settings.arguments as VenueApplicationArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenueApplicationScreen(args: args),
        );
      case AppRoutes.venuePending:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => VenuePendingScreen(),
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
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudioProfileScreen(),
        );
      case AppRoutes.studioPublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudioPublicProfileScreen(),
        );
      case AppRoutes.listenerProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ListenerProfileScreen(),
        );
      case AppRoutes.overthinkingFeed:
        final args = settings.arguments as OverthinkingFeedArgs?;
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
        final args = settings.arguments as TableGroupListArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TableGroupListScreen(
            args: args ?? const TableGroupListArgs(),
          ),
        );
      case AppRoutes.tableGroupCreate:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TableGroupCreateScreen(),
        );
      case AppRoutes.tableGroupDetail:
        final args = settings.arguments as TableGroupDetailArgs?;
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
        final args = settings.arguments as BackstageProfilesHomeArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BackstageProfilesHomeScreen(
            profileImageUrl: args?.profileImageUrl,
          ),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BackstageProfilesHomeScreen(),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginScreen(),
        );
    }
  }
}
