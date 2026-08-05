import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import 'backstage_profile_search_sheet.dart';
import 'musician_profile_screen.dart';
import 'profile_public_bottom_bar.dart';
import 'stage_home_top_bar.dart';
import 'studio_profile_screen.dart';

class BackstageProfilesHomeArgs {
  final String? profileImageUrl;

  const BackstageProfilesHomeArgs({this.profileImageUrl});
}

class BackstageProfilesHomeScreen extends StatelessWidget {
  final String? profileImageUrl;

  const BackstageProfilesHomeScreen({super.key, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            StageHomeTopBar(
              onSearchTap: () => showBackstageProfileSearch(context),
              onMenuTap: () => _showHomeQuickMenu(context),
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
      bottomNavigationBar: ProfilePublicBottomBar(
        currentIndex: 0,
        profileImageUrl: profileImageUrl,
      ),
    );
  }

  Future<void> _showHomeQuickMenu(BuildContext context) async {
    final roles = serviceLocator<AuthSessionManager>().session.normalizedRoles;
    final isStudio = roles.contains('ROLE_STUDIO') || roles.contains('STUDIO');
    await showProfileQuickMenu(
      context,
      settingsTileKey: const Key('backstage-account-settings'),
      profileContactTileKey: isStudio
          ? const Key('backstage-studio-profile-contact-editor')
          : null,
      onSettings: () async {
        await Navigator.of(context).pushNamed(AppRoutes.settings);
      },
      onProfileContact: isStudio
          ? () async {
              await Navigator.of(context).pushNamed(
                AppRoutes.studioProfile,
                arguments: const StudioProfileScreenArgs(
                  openContactEditor: true,
                ),
              );
            }
          : null,
      onManagement: () => _openBackstageManagementPanel(context),
    );
  }

  Future<void> _openBackstageManagementPanel(BuildContext context) async {
    final session = serviceLocator<AuthSessionManager>().session;
    final roles = session.normalizedRoles;
    if (session.isAdmin) {
      Navigator.of(context).pushNamed(AppRoutes.adminDashboard);
      return;
    }
    if (roles.contains('ROLE_MUSICIAN') || roles.contains('MUSICIAN')) {
      Navigator.of(context).pushNamed(
        AppRoutes.musicianProfile,
        arguments: const MusicianProfileScreenArgs(openManagementPanel: true),
      );
      return;
    }
    if (roles.contains('ROLE_VENUE') || roles.contains('VENUE')) {
      Navigator.of(context).pushNamed(AppRoutes.venueProfile);
      return;
    }
    if (roles.contains('ROLE_LISTENER') || roles.contains('LISTENER')) {
      Navigator.of(context).pushNamed(AppRoutes.listenerProfile);
      return;
    }
    if (roles.contains('ROLE_STUDIO') || roles.contains('STUDIO')) {
      Navigator.of(context).pushNamed(AppRoutes.studioProfile);
      return;
    }
    final isPlannedRole =
        roles.contains('ROLE_PRODUCER') ||
        roles.contains('PRODUCER') ||
        roles.contains('ROLE_ORGANIZER') ||
        roles.contains('ORGANIZER');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPlannedRole
              ? 'Bu rolun yonetim alani henuz hazir degil.'
              : 'Bu hesap icin uygun yonetim alani bulunamadi.',
        ),
      ),
    );
  }
}
