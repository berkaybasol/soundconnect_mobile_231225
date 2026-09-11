import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../../musician_feed/presentation/cubit/musician_feed_cubit.dart';
import '../../../musician_feed/presentation/screens/musician_feed_view.dart';
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
    final roles = serviceLocator<AuthSessionManager>().session.normalizedRoles;
    final isMusician =
        roles.contains('ROLE_MUSICIAN') || roles.contains('MUSICIAN');
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            StageHomeTopBar(
              onSearchTap: () => showBackstageProfileSearch(context),
              onMenuTap: () => _showHomeQuickMenu(context),
            ),
            Expanded(
              child: isMusician
                  ? BlocProvider(
                      create: (_) =>
                          serviceLocator<MusicianFeedCubit>()..initialize(),
                      child: const MusicianFeedView(),
                    )
                  : const SizedBox.expand(),
            ),
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
      appSnackBar(
        context,
        tone: AppSnackBarTone.info,
        content: Text(
          isPlannedRole
              ? 'Bu rolün yönetim alanı henüz hazır değil.'
              : 'Bu hesap için uygun yönetim alanı bulunamadı.',
        ),
      ),
    );
  }
}
