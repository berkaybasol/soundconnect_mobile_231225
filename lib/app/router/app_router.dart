import 'package:flutter/material.dart';
import '../../modules/auth/presentation/screens/login_screen.dart';
import '../../modules/auth/presentation/screens/register_screen.dart';
import '../../modules/auth/presentation/screens/otp_verify_screen.dart';
import '../../modules/auth/presentation/screens/venue_application_screen.dart';
import '../../modules/auth/presentation/screens/venue_pending_screen.dart';
import '../../modules/dm/presentation/screens/dm_chat_screen.dart';
import '../../modules/dm/presentation/screens/dm_conversations_screen.dart';
import '../../modules/profile/presentation/screens/musician_profile_screen.dart';
import '../../modules/profile/presentation/screens/musician_public_profile_screen.dart';
import '../../modules/profile/presentation/screens/create_band_screen.dart';
import '../../modules/profile/presentation/screens/band_profile_screen.dart';
import '../../modules/profile/presentation/screens/my_bands_screen.dart';
import '../../modules/profile/presentation/screens/venue_profile_screen.dart';
import '../../modules/profile/presentation/screens/venue_public_profile_screen.dart';
import '../app_shell.dart';
import 'app_routes.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case AppRoutes.register:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RegisterScreen(),
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
          builder: (_) => const VenuePendingScreen(),
        );
      case AppRoutes.musicianProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MusicianProfileScreen(),
        );
      case AppRoutes.myBands:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MyBandsScreen(),
        );
      case AppRoutes.createBand:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CreateBandScreen(),
        );
      case AppRoutes.bandProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BandProfileScreen(),
        );
      case AppRoutes.bandMemberProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BandProfileScreen(),
        );
      case AppRoutes.bandPublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const BandProfileScreen(),
        );
      case AppRoutes.musicianPublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MusicianPublicProfileScreen(),
        );
      case AppRoutes.venueProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const VenueProfileScreen(),
        );
      case AppRoutes.venuePublicProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const VenuePublicProfileScreen(),
        );
      case AppRoutes.dmConversations:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DmConversationsScreen(),
        );
      case AppRoutes.dmChat:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DmChatScreen(),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
    }
  }
}
