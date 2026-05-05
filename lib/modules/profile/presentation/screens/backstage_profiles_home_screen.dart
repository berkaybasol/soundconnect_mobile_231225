import 'package:flutter/material.dart';

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
            const StageHomeTopBar(),
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
}
