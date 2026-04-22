import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../dm/presentation/cubit/dm_badge_cubit.dart';
import '../../../dm/presentation/cubit/dm_badge_state.dart';
import '../../../../shared/theme/app_colors.dart';

class ProfilePublicBottomBar extends StatelessWidget {
  final int currentIndex;
  final String? profileImageUrl;

  ProfilePublicBottomBar({
    super.key,
    this.currentIndex = 3,
    this.profileImageUrl,
  });

  Widget _profileAvatar(BuildContext context, bool active) {
    final hasImage = profileImageUrl?.trim().isNotEmpty == true;
    final imageUrl = profileImageUrl?.trim() ?? '';
    final child = hasImage
        ? ClipOval(
            child: Image.network(
              imageUrl,
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

  @override
  Widget build(BuildContext context) {
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
              if (index == 2) {
                Navigator.of(context).pushNamed(AppRoutes.dmConversations);
                return;
              }
              if (index == 3) {
                Navigator.of(context).pushNamed(AppRoutes.musicianProfile);
              }
            },
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.campaign_outlined),
                label: 'Ilan',
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
            ],
          );
        },
      ),
    );
  }
}

class _ForumIconWithBadge extends StatelessWidget {
  final int unreadCount;

  _ForumIconWithBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) {
      return Icon(Icons.forum_outlined);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.forum_outlined),
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
