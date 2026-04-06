import 'package:flutter/material.dart';

import '../../domain/entities/media_asset.dart';
import 'profile_owner_video_tab.dart';

class ProfileMediaContentSwitcher extends StatelessWidget {
  final Widget firstTab;
  final List<MediaAsset> videoItems;
  final String videoProfileId;
  final bool ownerMode;
  final String profileType;
  final String uploadOwnerType;

  const ProfileMediaContentSwitcher({
    super.key,
    required this.firstTab,
    required this.videoItems,
    required this.videoProfileId,
    required this.ownerMode,
    required this.profileType,
    required this.uploadOwnerType,
  });

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return IndexedStack(
          index: controller.index,
          children: [
            firstTab,
            ProfileOwnerVideoTab(
              items: videoItems,
              profileId: videoProfileId,
              ownerMode: ownerMode,
              profileType: profileType,
              uploadOwnerType: uploadOwnerType,
            ),
          ],
        );
      },
    );
  }
}
