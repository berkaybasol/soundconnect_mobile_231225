import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../dm/presentation/cubit/dm_badge_cubit.dart';
import '../../../dm/presentation/cubit/dm_badge_state.dart';
import '../../../../shared/theme/app_colors.dart';

class ProfilePublicBottomBar extends StatelessWidget {
  final int currentIndex;

  const ProfilePublicBottomBar({super.key, this.currentIndex = 3});

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
            selectedItemColor: AppColors.textMuted,
            unselectedItemColor: AppColors.textMuted,
            onTap: (index) {
              if (index == 2) {
                Navigator.of(context).pushNamed(AppRoutes.dmConversations);
              }
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.campaign_outlined),
                label: 'Ilan',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.rocket_launch_outlined),
                label: 'Git',
              ),
              BottomNavigationBarItem(
                icon: _ForumIconWithBadge(unreadCount: state.unreadCount),
                label: 'Mesajlar',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
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

  const _ForumIconWithBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) {
      return const Icon(Icons.forum_outlined);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.forum_outlined),
        Positioned(
          right: -7,
          top: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: AppColors.coralAlt,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
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
