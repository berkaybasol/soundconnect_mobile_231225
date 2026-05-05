import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../dm/presentation/cubit/dm_badge_cubit.dart';
import '../../../dm/presentation/cubit/dm_badge_state.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'backstage_profiles_home_screen.dart';
import 'profile_bottom_bar_avatar_cache.dart';

class ProfilePublicBottomBar extends StatelessWidget {
  final int currentIndex;
  final String? profileImageUrl;
  final StageMode stageMode;

  ProfilePublicBottomBar({
    super.key,
    this.currentIndex = 4,
    this.profileImageUrl,
    this.stageMode = StageMode.backstage,
  });

  Widget _profileAvatar(BuildContext context, bool active, String? imageUrl) {
    final hasImage = imageUrl?.trim().isNotEmpty == true;
    final safeImageUrl = imageUrl?.trim() ?? '';
    final child = hasImage
        ? ClipOval(
            child: Image.network(
              safeImageUrl,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_outline, size: 18),
            ),
          )
        : const Icon(Icons.person_outline, size: 18);

    if (!active) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(child: child),
      );
    }

    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navBlueDeep,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.navBlueDeep, width: 1),
        ),
        child: Center(child: child),
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
    String? resolvedProfileImageUrl,
  ) {
    return [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Akis'),
      BottomNavigationBarItem(icon: _announcementIcon(context), label: 'Ilan'),
      BottomNavigationBarItem(
        icon: Icon(Icons.rocket_launch_outlined),
        label: 'Git',
      ),
      BottomNavigationBarItem(
        icon: _ForumIconWithBadge(unreadCount: state.unreadCount),
        label: 'Mesajlar',
      ),
      BottomNavigationBarItem(
        icon: _profileAvatar(context, false, resolvedProfileImageUrl),
        activeIcon: _profileAvatar(context, true, resolvedProfileImageUrl),
        label: 'Profil',
      ),
    ];
  }

  List<BottomNavigationBarItem> _mainstageItems(
    BuildContext context,
    DmBadgeState state,
    String? resolvedProfileImageUrl,
  ) {
    return [
      BottomNavigationBarItem(icon: Icon(Icons.circle_outlined), label: 'Bos'),
      BottomNavigationBarItem(
        icon: _assetIcon(context, 'assets/confined.png'),
        label: 'Overthinking',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.circle_outlined), label: 'Bos'),
      BottomNavigationBarItem(
        icon: _ForumIconWithBadge(unreadCount: state.unreadCount),
        label: 'Mesajlar',
      ),
      BottomNavigationBarItem(
        icon: _profileAvatar(context, false, resolvedProfileImageUrl),
        activeIcon: _profileAvatar(context, true, resolvedProfileImageUrl),
        label: 'Profil',
      ),
    ];
  }

  void _handleBackstageTap(
    BuildContext context,
    int index,
    String? resolvedProfileImageUrl,
  ) {
    if (index == 0) {
      if (currentIndex == 0) return;
      Navigator.of(context).pushNamed(
        AppRoutes.backstageProfilesHome,
        arguments: BackstageProfilesHomeArgs(
          profileImageUrl: resolvedProfileImageUrl,
        ),
      );
      return;
    }
    if (index == 3) {
      if (currentIndex == 3) return;
      Navigator.of(context).pushNamed(AppRoutes.dmConversations);
      return;
    }
    if (index == 2) {
      _showMainstageLauncher(context);
      return;
    }
    if (index == 4) {
      if (currentIndex == 4) return;
      _openBackstageProfile(context);
    }
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
                  icon: Icons.circle_outlined,
                  label: 'Bos',
                  description: 'Yakinda',
                  enabled: false,
                  onTap: null,
                ),
                const SizedBox(height: 8),
                _MainstageLauncherTile(
                  icon: Icons.circle_outlined,
                  label: 'Bos',
                  description: 'Yakinda',
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
    Navigator.of(context).pushNamed(
      route,
      arguments: const OverthinkingFeedArgs(
        bottomBarStageMode: StageMode.backstage,
      ),
    );
  }

  void _handleMainstageTap(BuildContext context, int index) {
    if (index == 1) {
      if (currentIndex == 1) return;
      Navigator.of(context).pushNamed(AppRoutes.overthinkingFeed);
      return;
    }
    if (index == 3) {
      if (currentIndex == 3) return;
      Navigator.of(context).pushNamed(AppRoutes.dmConversations);
      return;
    }
    if (index == 4) {
      if (currentIndex == 4) return;
      Navigator.of(context).pushNamed(AppRoutes.listenerProfile);
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
                _handleMainstageTap(context, index);
                return;
              }
              _handleBackstageTap(context, index, resolvedProfileImageUrl);
            },
            items: stageMode == StageMode.mainstage
                ? _mainstageItems(context, state, resolvedProfileImageUrl)
                : _backstageItems(context, state, resolvedProfileImageUrl),
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
