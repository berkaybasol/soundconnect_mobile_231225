part of 'profile_venue_support.dart';

class ProfileBottomBar extends StatelessWidget {
  final String? profileImageUrl;
  final int currentIndex;

  const ProfileBottomBar({
    super.key,
    this.profileImageUrl,
    this.currentIndex = 3,
  });

  Widget _profileAvatar(bool active) {
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
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: child),
      );
    }

    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(1.4),
      decoration: const BoxDecoration(
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
            selectedItemColor: AppColors.coralAlt,
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
              BottomNavigationBarItem(
                icon: _profileAvatar(false),
                activeIcon: _profileAvatar(true),
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
    if (unreadCount <= 0) return const Icon(Icons.forum_outlined);
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
