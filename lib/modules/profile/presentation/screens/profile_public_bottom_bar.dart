import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/access_policy.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../dm/presentation/cubit/dm_badge_cubit.dart';
import '../../../dm/presentation/cubit/dm_badge_state.dart';
import '../../../event/presentation/screens/event_discovery_screen.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../../overthinking/presentation/widgets/overthinking_unread_dot.dart';
import '../../../tablegroup/presentation/screens/table_group_route_args.dart';
import 'profile_bottom_navigation.dart';
import 'profile_bottom_bar_avatar_cache.dart';

class ProfilePublicBottomBar extends StatelessWidget {
  final int currentIndex;
  final String? profileImageUrl;
  final StageMode stageMode;
  final int? mainstageCurrentIndex;
  final bool profileTapAlwaysOpensOwnProfile;
  final FutureOr<bool> Function()? onBeforeNavigate;
  final ValueChanged<int>? onDestinationSelected;
  final int? unreadCountOverride;
  final bool allowCurrentDestinationNavigation;

  ProfilePublicBottomBar({
    super.key,
    this.currentIndex = 4,
    this.profileImageUrl,
    this.stageMode = StageMode.backstage,
    this.mainstageCurrentIndex,
    this.profileTapAlwaysOpensOwnProfile = false,
    this.onBeforeNavigate,
    this.onDestinationSelected,
    this.unreadCountOverride,
    this.allowCurrentDestinationNavigation = false,
  });

  Widget _profileAvatar(BuildContext context, bool active) {
    return const Icon(Icons.person_outline_rounded);
  }

  Widget _announcementIcon(BuildContext context) {
    return const Icon(Icons.handshake_outlined);
  }

  Widget _assetIcon(BuildContext context, String assetName) {
    return Builder(
      builder: (iconContext) => ColorFiltered(
        colorFilter: ColorFilter.mode(
          IconTheme.of(iconContext).color ??
              Theme.of(iconContext).colorScheme.onSurfaceVariant,
          BlendMode.srcIn,
        ),
        child: Image.asset(assetName, width: 22, height: 22),
      ),
    );
  }

  Widget _discoveryIcon(BuildContext context) {
    return _assetIcon(context, 'assets/music-note.png');
  }

  List<BottomNavigationBarItem> _backstageItems(
    BuildContext context,
    int unreadCount,
    bool canAccessMarketplace,
  ) {
    return [
      if (canAccessMarketplace)
        const BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront_outlined),
          label: 'Pazar',
          tooltip: 'Ekipman Pazarı',
        )
      else
        const BottomNavigationBarItem(
          icon: SizedBox(
            key: Key('backstage-reserved-navigation-slot'),
            width: 24,
            height: 24,
          ),
          label: '',
          tooltip: '',
        ),
      BottomNavigationBarItem(
        icon: _announcementIcon(context),
        label: 'Collab',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.rocket_launch_outlined),
        label: 'Git',
      ),
      BottomNavigationBarItem(
        icon: _ForumIconWithBadge(unreadCount: unreadCount),
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
    int unreadCount,
  ) {
    return [
      BottomNavigationBarItem(
        icon: _discoveryIcon(context),
        activeIcon: _discoveryIcon(context),
        label: 'Keşfet',
      ),
      BottomNavigationBarItem(
        icon: OverthinkingBoundUnreadDot(
          badgeKey: const ValueKey('overthinking-navigation-unread-dot'),
          child: const Icon(Icons.bubble_chart_outlined),
        ),
        label: 'Overthinking',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.groups_2_outlined),
        label: 'Müzik Birleştirir!',
      ),
      BottomNavigationBarItem(
        icon: _ForumIconWithBadge(unreadCount: unreadCount),
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
    final current = _navigationFence(context);
    if (!context.mounted || !current()) return;
    if (index != 2 &&
        index == currentIndex &&
        !(index == 4 && profileTapAlwaysOpensOwnProfile)) {
      return;
    }
    if (!await _navigationAllowed()) return;
    if (!context.mounted || !current()) return;
    if (index == 0) {
      replaceProfileBottomNavigationRoute(context, AppRoutes.marketplace);
      return;
    }
    if (index == 1) {
      final token = await serviceLocator<TokenStore>().readToken();
      if (!context.mounted || !current()) return;
      if (!AccessPolicy.canAccessCollab(_rolesFromToken(token))) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.warning,
            content: const Text(
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

  bool Function() _sessionFence() {
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    final expected = manager?.session;
    return () => manager == null || identical(manager.session, expected);
  }

  bool Function() _navigationFence(BuildContext context) {
    final route = ModalRoute.of(context);
    final sameSession = _sessionFence();
    return () => context.mounted && route?.isCurrent == true && sameSession();
  }

  Future<void> _openBackstageProfile(BuildContext context) async {
    await _openProfileForCurrentRole(context);
  }

  Future<void> _openProfileForCurrentRole(BuildContext context) async {
    final current = _navigationFence(context);
    if (!context.mounted || !current()) return;
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    // The live session is authoritative; storage can still contain a token
    // from the account that is being replaced.
    final List<String> currentRoles;
    if (manager != null) {
      currentRoles = manager.session.isAuthenticated && manager.session.isActive
          ? manager.session.roles
          : const [];
    } else {
      currentRoles = _rolesFromToken(
        await serviceLocator<TokenStore>().readToken(),
      );
    }
    if (!context.mounted || !current()) return;
    final roles = currentRoles.map((role) => role.trim().toUpperCase()).toSet();
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
      appSnackBar(
        context,
        tone: AppSnackBarTone.info,
        content: const Text('Bu rol için profil ekranı henüz hazır değil.'),
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
    final current = _navigationFence(context);
    final sameSession = _sessionFence();
    if (!context.mounted || !current()) return;
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    ModalRoute<dynamic>? sheetRoute;
    void sessionChanged() {
      if (sameSession()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheetRoute?.isActive == true) {
          sheetRoute!.navigator?.removeRoute(sheetRoute!);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    manager?.addListener(sessionChanged);
    String? route;
    try {
      route = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (sheetContext) {
          sheetRoute = ModalRoute.of(sheetContext);
          if (!sameSession()) {
            sessionChanged();
            return const SizedBox.shrink();
          }
          void select(String destination) {
            if (sheetContext.mounted &&
                sheetRoute?.isCurrent == true &&
                sameSession()) {
              Navigator.of(sheetContext).pop(destination);
            }
          }

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
                    showOverthinkingUnread: true,
                    label: 'Overthinking',
                    description: 'Overthinking akışına geç',
                    enabled: true,
                    onTap: () => select(AppRoutes.overthinkingFeed),
                  ),
                  const SizedBox(height: 8),
                  _MainstageLauncherTile(
                    icon: Icons.groups_2_outlined,
                    label: 'Müzik Birleştirir!',
                    description: 'Masalara geç',
                    enabled: true,
                    onTap: () => select(AppRoutes.tableGroupList),
                  ),
                  const SizedBox(height: 8),
                  _MainstageLauncherTile(
                    assetName: 'assets/music-note.png',
                    label: 'Keşfet',
                    description: 'Konumuna göre canlı müzik etkinliklerini bul',
                    enabled: true,
                    onTap: () => select(AppRoutes.eventDiscovery),
                  ),
                ],
              ),
            ),
          );
        },
      );
      await sheetRoute?.completed;
    } finally {
      manager?.removeListener(sessionChanged);
    }

    if (route == null || !context.mounted || !current()) {
      return;
    }
    if (route == AppRoutes.eventDiscovery) {
      replaceProfileBottomNavigationRoute(
        context,
        route,
        arguments: const EventDiscoveryArgs(
          bottomBarStageMode: StageMode.backstage,
        ),
      );
      return;
    }
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
    final current = _navigationFence(context);
    if (!context.mounted || !current()) return;
    if (!allowCurrentDestinationNavigation &&
        index == (mainstageCurrentIndex ?? currentIndex) &&
        !(index == 4 && profileTapAlwaysOpensOwnProfile)) {
      return;
    }
    if (!await _navigationAllowed()) return;
    if (!context.mounted || !current()) return;
    if (index == 0) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      replaceProfileBottomNavigationRoute(context, AppRoutes.eventDiscovery);
      return;
    }
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
    Theme.of(context);
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    if (manager == null) return _buildForViewer(context, null);
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) => _buildForViewer(context, manager),
    );
  }

  Widget _buildForViewer(BuildContext context, AuthSessionManager? manager) {
    final session = manager?.session;
    final canAccessMarketplace =
        session != null &&
        session.isAuthenticated &&
        session.isActive &&
        AccessPolicy.canAccessMarketplace(session.roles);
    final effectiveStage = StageModeResolver.forViewer(
      session,
      requested: stageMode,
    );
    final resolvedProfileImageUrl = (profileImageUrl?.trim().isNotEmpty == true)
        ? profileImageUrl!.trim()
        : ProfileBottomBarAvatarCache.lastProfileImageUrl;
    ProfileBottomBarAvatarCache.remember(resolvedProfileImageUrl);

    Widget navigation(int unreadCount) {
      final scheme = Theme.of(context).colorScheme;
      final light = scheme.brightness == Brightness.light;
      final activeIndex = effectiveStage == StageMode.mainstage
          ? mainstageCurrentIndex ?? currentIndex
          : currentIndex;
      final items = effectiveStage == StageMode.mainstage
          ? _mainstageItems(context, unreadCount)
          : _backstageItems(context, unreadCount, canAccessMarketplace);
      final accent = light
          ? AppColors.lightPalette.coral
          : AppColors.originalDark.coralLight;
      final surface = light
          ? scheme.surface
          : Color.lerp(scheme.surface, scheme.surfaceContainerHighest, .35)!;
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: light ? .65 : .5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: light ? .06 : .2),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: BottomNavigationBar(
                currentIndex: activeIndex,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconSize: 22,
                selectedItemColor: accent,
                unselectedItemColor: scheme.onSurfaceVariant.withValues(
                  alpha: .82,
                ),
                selectedFontSize: 11,
                unselectedFontSize: 11,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                onTap: (index) {
                  if (!canAccessMarketplace &&
                      effectiveStage == StageMode.backstage &&
                      index == 0) {
                    return;
                  }
                  if (manager != null && !identical(manager.session, session)) {
                    return;
                  }
                  final selected = onDestinationSelected;
                  if (selected != null) {
                    selected(index);
                    return;
                  }
                  if (effectiveStage == StageMode.mainstage) {
                    unawaited(_handleMainstageTap(context, index));
                    return;
                  }
                  unawaited(
                    _handleBackstageTap(
                      context,
                      index,
                      resolvedProfileImageUrl,
                    ),
                  );
                },
                items: [
                  for (var index = 0; index < items.length; index++)
                    BottomNavigationBarItem(
                      label: items[index].label,
                      tooltip: items[index].tooltip,
                      icon: _BottomBarGlyph(
                        active:
                            index == activeIndex && items[index].label != '',
                        launcher:
                            effectiveStage == StageMode.backstage && index == 2,
                        child: index == activeIndex
                            ? items[index].activeIcon
                            : items[index].icon,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (unreadCountOverride case final count?) return navigation(count);
    final badgeCubit = serviceLocator<DmBadgeCubit>()..ensureStarted();
    return BlocProvider<DmBadgeCubit>.value(
      value: badgeCubit,
      child: BlocBuilder<DmBadgeCubit, DmBadgeState>(
        builder: (context, state) => navigation(state.unreadCount),
      ),
    );
  }
}

class _BottomBarGlyph extends StatelessWidget {
  const _BottomBarGlyph({
    required this.active,
    required this.launcher,
    required this.child,
  });

  final bool active, launcher;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brandColors = scheme.brightness == Brightness.light
        ? AppColors.lightPalette.brandGradient
        : AppColors.originalDark.brandGradient;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GradientOutline(
        radius: 13,
        strokeWidth: .8,
        colors: [
          for (final color in brandColors)
            color.withValues(alpha: active ? .48 : 0),
        ],
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                for (final color in brandColors)
                  active
                      ? color.withValues(alpha: .16)
                      : launcher
                      ? scheme.onSurface.withValues(alpha: .035)
                      : Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: launcher && !active
                  ? scheme.outlineVariant.withValues(alpha: .6)
                  : Colors.transparent,
            ),
          ),
          child: Center(child: child),
        ),
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
  final bool showOverthinkingUnread;

  const _MainstageLauncherTile({
    this.icon,
    this.assetName,
    required this.label,
    required this.description,
    required this.enabled,
    required this.onTap,
    this.showOverthinkingUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final textColor = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    final leading = GradientOutline(
      enabled: AppColors.isLight,
      radius: 18,
      colors: enabled
          ? null
          : [Theme.of(context).dividerColor, Theme.of(context).dividerColor],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled && AppColors.isOriginalDark
              ? LinearGradient(colors: AppColors.decorativeGradient)
              : null,
          color: enabled || AppColors.isLight
              ? null
              : Theme.of(context).disabledColor,
        ),
        child: assetName == null
            ? Icon(
                icon ?? Icons.circle_outlined,
                color: enabled
                    ? AppColors.decorativeForeground
                    : AppColors.isLight
                    ? AppColors.textMuted
                    : AppColors.navBlueDeep,
                size: 20,
              )
            : Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    enabled
                        ? AppColors.decorativeForeground
                        : AppColors.isLight
                        ? AppColors.textMuted
                        : AppColors.navBlueDeep,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(assetName!, width: 21, height: 21),
                ),
              ),
      ),
    );
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
            if (showOverthinkingUnread)
              OverthinkingBoundUnreadDot(
                badgeKey: const ValueKey('overthinking-launcher-unread-dot'),
                child: leading,
              )
            else
              leading,
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
    return const Icon(Icons.chat_bubble_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
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
                  color: AppColors.onAccent,
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
