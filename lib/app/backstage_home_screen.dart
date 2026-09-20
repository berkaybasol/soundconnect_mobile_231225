import 'package:flutter/material.dart';

import '../core/auth/auth_session_manager.dart';
import '../core/di/service_locator.dart';
import '../core/policy/access_policy.dart';
import '../modules/marketplace/presentation/screens/marketplace_screen.dart';
import '../modules/profile/presentation/screens/backstage_profiles_home_screen.dart';
import '../modules/profile/presentation/screens/profile_public_bottom_bar.dart';

/// Resolves the launch surface against the live identity, including account
/// switches that happen without reconstructing the application's Navigator.
class BackstageHomeScreen extends StatelessWidget {
  const BackstageHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = serviceLocator<AuthSessionManager>();
    return ListenableBuilder(
      listenable: sessions,
      builder: (context, _) {
        final session = sessions.session;
        if (session.isAuthenticated &&
            session.isActive &&
            AccessPolicy.canAccessMarketplace(session.roles)) {
          return MarketplaceScreen(
            key: ValueKey(session),
            bottomNavigationBar: ProfilePublicBottomBar(currentIndex: 0),
          );
        }
        return const BackstageProfilesHomeScreen();
      },
    );
  }
}
