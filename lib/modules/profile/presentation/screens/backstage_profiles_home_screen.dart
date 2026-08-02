import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import 'backstage_profile_search_sheet.dart';
import 'musician_profile_screen.dart';
import 'profile_public_bottom_bar.dart';
import 'stage_home_top_bar.dart';

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
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.surface,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  left: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        ListTile(
                          key: const Key('backstage-account-settings'),
                          leading: const Icon(Icons.settings_outlined),
                          title: const Text('Ayarlar'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pushNamed(AppRoutes.settings);
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.dashboard_customize_outlined,
                          ),
                          title: const Text('Yönetim Paneli'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _openBackstageManagementPanel(context);
                          },
                        ),
                        ListTile(
                          key: profileMenuThemeTileKey,
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Tema'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showProfileMenuThemePicker(context);
                          },
                        ),
                        ListTile(
                          key: profileMenuSupportTileKey,
                          leading: const Icon(Icons.support_agent_rounded),
                          title: const Text('Destek'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showProfileMenuSupport(context);
                          },
                        ),
                        const Spacer(),
                        SessionLogoutMenuTile(
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await confirmAndLogoutSession(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
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
