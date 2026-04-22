part of 'band_profile_screen.dart';

class _BandSocialButtonRow extends StatelessWidget {
  final BandProfile profile;
  final bool editable;
  final ValueChanged<ProfileSocialPlatform>? onAddLink;

  _BandSocialButtonRow({
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

    if (visible.isEmpty) return SizedBox.shrink();

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

  _BandSocialItem({required this.platform, required this.url});

  bool get active {
    final value = url?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('www.');
  }
}

class _BandSocialPill extends StatelessWidget {
  final FaIconData icon;
  final bool active;
  final bool showAddBadge;
  final VoidCallback onTap;

  _BandSocialPill({
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Center(
              child: FaIcon(
                icon,
                size: 20,
                color: active
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
                decoration: BoxDecoration(
                  color: AppColors.coralAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, size: 12, color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }
}
