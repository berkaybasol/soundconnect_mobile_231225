import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
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
                        const Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.settings_outlined),
                            title: Text('Ayarlar'),
                          ),
                        ),
                        const Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.assignment_outlined),
                            title: Text('Başvurularım'),
                          ),
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
                        const Spacer(),
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

  Future<void> _openBackstageProfile(BuildContext context) async {
    final token = await serviceLocator<TokenStore>().readToken();
    if (!context.mounted) return;
    final roles = _rolesFromToken(
      token,
    ).map((role) => role.trim().toUpperCase()).toSet();
    if (roles.contains('ROLE_VENUE') || roles.contains('VENUE')) {
      Navigator.of(context).pushNamed(AppRoutes.venueProfile);
      return;
    }
    if (roles.contains('ROLE_LISTENER') || roles.contains('LISTENER')) {
      Navigator.of(context).pushNamed(AppRoutes.listenerProfile);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.musicianProfile);
  }

  Future<void> _openBackstageManagementPanel(BuildContext context) async {
    final token = await serviceLocator<TokenStore>().readToken();
    if (!context.mounted) return;
    final roles = _rolesFromToken(
      token,
    ).map((role) => role.trim().toUpperCase()).toSet();
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
    Navigator.of(context).pushNamed(
      AppRoutes.musicianProfile,
      arguments: const MusicianProfileScreenArgs(openManagementPanel: true),
    );
  }

  List<String> _rolesFromToken(String? token) {
    final raw = token?.trim() ?? '';
    if (raw.isEmpty) return const [];
    final parts = raw.split('.');
    if (parts.length < 2) return const [];
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return const [];
      final rolesValue = map['roles'] ?? map['authorities'] ?? map['role'];
      if (rolesValue is List) {
        return rolesValue
            .map((role) => role.toString().trim())
            .where((role) => role.isNotEmpty)
            .toList();
      }
      if (rolesValue is String) {
        return rolesValue
            .split(',')
            .map((role) => role.trim())
            .where((role) => role.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
