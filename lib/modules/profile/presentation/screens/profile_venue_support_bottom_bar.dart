part of 'profile_venue_support.dart';

class ProfileBottomBar extends StatelessWidget {
  final String? profileImageUrl;
  final int currentIndex;

  ProfileBottomBar({super.key, this.profileImageUrl, this.currentIndex = 4});

  @override
  Widget build(BuildContext context) {
    return ProfilePublicBottomBar(
      currentIndex: currentIndex,
      profileImageUrl: profileImageUrl,
    );
  }
}
