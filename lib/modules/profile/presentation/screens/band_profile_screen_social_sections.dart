part of 'band_profile_screen.dart';

class _BandSocialButtonRow extends StatelessWidget {
  final BandProfile profile;
  final bool editable;
  final ValueChanged<ProfileSocialPlatform>? onAddLink;

  const _BandSocialButtonRow({
    required this.profile,
    required this.editable,
    required this.onAddLink,
  });

  String? _urlFor(ProfileSocialPlatform platform) {
    switch (platform) {
      case ProfileSocialPlatform.soundcloud:
        return profile.soundCloudUrl;
      case ProfileSocialPlatform.instagram:
        return profile.instagramUrl;
      case ProfileSocialPlatform.youtube:
        return profile.youtubeUrl;
      case ProfileSocialPlatform.spotify:
        return profile.spotifyEmbedUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ProfileSocialPlatform.values
        .map(
          (platform) =>
              _BandSocialItem(platform: platform, url: _urlFor(platform)),
        )
        .toList();

    final visible = editable
        ? items
        : items.where((item) => item.active).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: visible.map((item) {
        return _BandSocialPill(
          icon: item.platform.icon,
          active: item.active,
          showAddBadge: editable && !item.active,
          onTap: () => onAddLink?.call(item.platform),
        );
      }).toList(),
    );
  }
}

class _BandSocialItem {
  final ProfileSocialPlatform platform;
  final String? url;

  const _BandSocialItem({required this.platform, required this.url});

  bool get active {
    final value = url?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('www.');
  }
}

class _BandSocialPill extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool showAddBadge;
  final VoidCallback onTap;

  const _BandSocialPill({
    required this.icon,
    required this.active,
    required this.showAddBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: active ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          if (showAddBadge)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.coralAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
