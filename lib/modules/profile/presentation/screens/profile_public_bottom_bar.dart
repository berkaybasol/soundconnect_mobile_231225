import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/access_policy.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../dm/presentation/cubit/dm_badge_cubit.dart';
import '../../../dm/presentation/cubit/dm_badge_state.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../../tablegroup/presentation/screens/table_group_route_args.dart';
import 'backstage_profiles_home_screen.dart';
import 'profile_bottom_navigation.dart';
import 'profile_bottom_bar_avatar_cache.dart';

class ProfilePublicBottomBar extends StatelessWidget {
  final int currentIndex;
  final String? profileImageUrl;
  final StageMode stageMode;
  final bool profileTapAlwaysOpensOwnProfile;
  final FutureOr<bool> Function()? onBeforeNavigate;

  ProfilePublicBottomBar({
    super.key,
    this.currentIndex = 4,
    this.profileImageUrl,
    this.stageMode = StageMode.backstage,
    this.profileTapAlwaysOpensOwnProfile = false,
    this.onBeforeNavigate,
  });

  Widget _profileAvatar(BuildContext context, bool active) {
    final tint = IconTheme.of(context).color;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint ?? Colors.white, BlendMode.srcIn),
      child: Image.asset(
        'assets/ME!2-transparent.png',
        width: active ? 25 : 23,
        height: active ? 25 : 23,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _announcementIcon(BuildContext context) {
    return const Icon(Icons.device_hub);
  }

  Widget _assetIcon(BuildContext context, String assetName) {
    final tint = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      child: Image.asset(assetName, width: 22, height: 22),
    );
  }

  List<BottomNavigationBarItem> _backstageItems(
    BuildContext context,
    DmBadgeState state,
  ) {
    return [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Akış'),
      BottomNavigationBarItem(
        icon: _announcementIcon(context),
        label: 'Collab',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.rocket_launch_outlined),
        label: 'Git',
      ),
      BottomNavigationBarItem(
        icon: _ForumIconWithBadge(unreadCount: state.unreadCount),
        label: 'Mesajlar',
      ),
      BottomNavigationBarItem(
        icon: _profileAvatar(context, false),
        activeIcon: _profileAvatar(context, true),
        label: 'Profil',
      ),
    ];
  }

  List<BottomNavigationBarItem> _mainstageItems(
    BuildContext context,
    DmBadgeState state,
  ) {
    return [
      BottomNavigationBarItem(
        icon: Icon(Icons.circle_outlined),
        label: 'Nabız',
      ),
      BottomNavigationBarItem(
        icon: _assetIcon(context, 'assets/confined.png'),
        label: 'Overthinking',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.groups_2_outlined),
        label: 'Müzik Birleştirir!',
      ),
      BottomNavigationBarItem(
        icon: _ForumIconWithBadge(unreadCount: state.unreadCount),
        label: 'Mesajlar',
      ),
      BottomNavigationBarItem(
        icon: _profileAvatar(context, false),
        activeIcon: _profileAvatar(context, true),
        label: 'Profil',
      ),
    ];
  }

  Future<void> _handleBackstageTap(
    BuildContext context,
    int index,
    String? resolvedProfileImageUrl,
  ) async {
    if (index != 2 &&
        index == currentIndex &&
        !(index == 4 && profileTapAlwaysOpensOwnProfile)) {
      return;
    }
    if (!await _navigationAllowed()) return;
    if (!context.mounted) return;
    if (index == 0) {
      replaceProfileBottomNavigationRoute(
        context,
        AppRoutes.backstageProfilesHome,
        arguments: BackstageProfilesHomeArgs(
          profileImageUrl: resolvedProfileImageUrl,
        ),
      );
      return;
    }
    if (index == 1) {
      final token = await serviceLocator<TokenStore>().readToken();
      if (!context.mounted) return;
      if (!AccessPolicy.canAccessCollab(_rolesFromToken(token))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Collab yalnız Müzisyen, Mekan ve Stüdyo profilleriyle kullanılabilir.',
            ),
          ),
        );
        return;
      }
      replaceProfileBottomNavigationRoute(context, AppRoutes.collabDiscovery);
      return;
    }
    if (index == 3) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.dmConversations);
      return;
    }
    if (index == 2) {
      _showMainstageLauncher(context);
      return;
    }
    if (index == 4) {
      _openBackstageProfile(context);
    }
  }

  Future<bool> _navigationAllowed() async {
    final callback = onBeforeNavigate;
    if (callback == null) return true;
    return await callback();
  }

  Future<void> _openBackstageProfile(BuildContext context) async {
    await _openProfileForCurrentRole(context);
  }

  Future<void> _openProfileForCurrentRole(BuildContext context) async {
    final token = await serviceLocator<TokenStore>().readToken();
    if (!context.mounted) return;
    final roles = _rolesFromToken(
      token,
    ).map((role) => role.trim().toUpperCase()).toSet();
    if (roles.contains('ROLE_STUDIO') || roles.contains('STUDIO')) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.studioProfile);
      return;
    }
    if (roles.contains('ROLE_VENUE') || roles.contains('VENUE')) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.venueProfile);
      return;
    }
    if (roles.contains('ROLE_LISTENER') || roles.contains('LISTENER')) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.listenerProfile);
      return;
    }
    if (roles.contains('ROLE_MUSICIAN') || roles.contains('MUSICIAN')) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.musicianProfile);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu rol icin profil ekrani henuz hazir degil.'),
      ),
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

  Future<void> _showMainstageLauncher(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                _MainstageLauncherTile(
                  assetName: 'assets/confined.png',
                  label: 'Overthinking',
                  description: 'Mainstage akisina gec',
                  enabled: true,
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(AppRoutes.overthinkingFeed),
                ),
                const SizedBox(height: 8),
                _MainstageLauncherTile(
                  icon: Icons.groups_2_outlined,
                  label: 'Müzik Birleştirir!',
                  description: 'Masalara geç',
                  enabled: true,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(AppRoutes.tableGroupList),
                ),
                const SizedBox(height: 8),
                const _MainstageLauncherTile(
                  icon: Icons.circle_outlined,
                  label: 'Nabız',
                  description: 'Yakında',
                  enabled: false,
                  onTap: null,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (route == null || !context.mounted) return;
    if (route == AppRoutes.tableGroupList) {
      replaceProfileBottomNavigationRoute(
        context,
        route,
        arguments: const TableGroupListArgs(
          bottomBarStageMode: StageMode.backstage,
        ),
      );
      return;
    }
    replaceProfileBottomNavigationRoute(
      context,
      route,
      arguments: const OverthinkingFeedArgs(
        bottomBarStageMode: StageMode.backstage,
      ),
    );
  }

  Future<void> _handleMainstageTap(BuildContext context, int index) async {
    if (index == currentIndex &&
        !(index == 4 && profileTapAlwaysOpensOwnProfile)) {
      return;
    }
    if (!await _navigationAllowed()) return;
    if (!context.mounted) return;
    if (index == 1) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.overthinkingFeed);
      return;
    }
    if (index == 2) {
      replaceProfileBottomNavigationRoute(
        context,
        AppRoutes.tableGroupList,
        arguments: const TableGroupListArgs(
          bottomBarStageMode: StageMode.mainstage,
        ),
      );
      return;
    }
    if (index == 3) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.dmConversations);
      return;
    }
    if (index == 4) {
      _openProfileForCurrentRole(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedProfileImageUrl = (profileImageUrl?.trim().isNotEmpty == true)
        ? profileImageUrl!.trim()
        : ProfileBottomBarAvatarCache.lastProfileImageUrl;
    ProfileBottomBarAvatarCache.remember(resolvedProfileImageUrl);

    final badgeCubit = serviceLocator<DmBadgeCubit>()..ensureStarted();
    return BlocProvider<DmBadgeCubit>.value(
      value: badgeCubit,
      child: BlocBuilder<DmBadgeCubit, DmBadgeState>(
        builder: (context, state) {
          return BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.navBlueDeep,
            selectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: (index) {
              if (stageMode == StageMode.mainstage) {
                unawaited(_handleMainstageTap(context, index));
                return;
              }
              unawaited(
                _handleBackstageTap(context, index, resolvedProfileImageUrl),
              );
            },
            items: stageMode == StageMode.mainstage
                ? _mainstageItems(context, state)
                : _backstageItems(context, state),
          );
        },
      ),
    );
  }
}

class _MainstageLauncherTile extends StatelessWidget {
  final IconData? icon;
  final String? assetName;
  final String label;
  final String description;
  final bool enabled;
  final VoidCallback? onTap;

  const _MainstageLauncherTile({
    this.icon,
    this.assetName,
    required this.label,
    required this.description,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: enabled
                    ? LinearGradient(colors: AppColors.brandGradient)
                    : null,
                color: enabled ? null : Theme.of(context).disabledColor,
              ),
              child: assetName == null
                  ? Icon(
                      icon ?? Icons.circle_outlined,
                      color: enabled ? AppColors.white : AppColors.navBlueDeep,
                      size: 20,
                    )
                  : Center(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          enabled ? AppColors.white : AppColors.navBlueDeep,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(assetName!, width: 21, height: 21),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              enabled ? Icons.chevron_right_rounded : Icons.lock_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForumIconWithBadge extends StatelessWidget {
  final int unreadCount;

  _ForumIconWithBadge({required this.unreadCount});

  Widget _dmIcon(BuildContext context) {
    final tint = IconTheme.of(context).color;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint ?? Colors.white, BlendMode.srcIn),
      child: Image.asset('assets/dm.png', width: 22, height: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) {
      return _dmIcon(context);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _dmIcon(context),
        Positioned(
          right: -7,
          top: -6,
          child: Container(
            constraints: BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.coralAlt,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
