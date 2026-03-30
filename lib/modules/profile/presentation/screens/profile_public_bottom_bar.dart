import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfilePublicBottomBar extends StatelessWidget {
  const ProfilePublicBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.navBlueDeep,
      selectedItemColor: AppColors.textMuted,
      unselectedItemColor: AppColors.textMuted,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.campaign_outlined),
          label: 'İlan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.rocket_launch_outlined),
          label: 'Git',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.forum_outlined),
          label: 'Mesajlar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    );
  }
}
