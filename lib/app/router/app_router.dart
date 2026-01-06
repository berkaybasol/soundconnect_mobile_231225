import 'package:flutter/material.dart';
import '../../modules/auth/presentation/screens/login_screen.dart';
import '../../modules/auth/presentation/screens/register_screen.dart';
import '../../modules/auth/presentation/screens/otp_verify_screen.dart';
import '../../modules/auth/presentation/screens/venue_application_screen.dart';
import '../../modules/auth/presentation/screens/venue_pending_screen.dart';
import '../app_shell.dart';
import 'app_routes.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case AppRoutes.otpVerify:
        return MaterialPageRoute(builder: (_) => const OtpVerifyScreen());
      case AppRoutes.venueApplication:
        final args = settings.arguments as VenueApplicationArgs?;
        return MaterialPageRoute(
          builder: (_) => VenueApplicationScreen(args: args),
        );
      case AppRoutes.venuePending:
        return MaterialPageRoute(builder: (_) => const VenuePendingScreen());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const AppShell());
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
