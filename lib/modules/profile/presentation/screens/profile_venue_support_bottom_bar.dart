part of 'profile_venue_support.dart';

class ProfileBottomBar extends StatelessWidget {
  final String? profileImageUrl;

  const ProfileBottomBar({super.key, this.profileImageUrl});

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
    return BottomNavigationBar(
      currentIndex: 3,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.navBlueDeep,
      selectedItemColor: AppColors.coralAlt,
      unselectedItemColor: AppColors.textMuted,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.campaign_outlined),
          label: 'Ilan',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.rocket_launch_outlined),
          label: 'Git',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.forum_outlined),
          label: 'Mesajlar',
        ),
        BottomNavigationBarItem(
          icon: _profileAvatar(false),
          activeIcon: _profileAvatar(true),
          label: 'Profil',
        ),
      ],
    );
  }
}
