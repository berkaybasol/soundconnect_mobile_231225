part of 'studio_profile_screen.dart';

class _StudioOwnerDashboardContent extends StatelessWidget {
  final StudioProfile profile;
  final String location;
  final int? followersCount;
  final int? followingCount;
  final bool photoUploading;
  final VoidCallback onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onEditPhoto;
  final VoidCallback onEditDescription;
  final ValueChanged<ProfileSocialPlatform> onEditSocialLink;
  final int contentRevision;
  final VoidCallback onManagement;

  const _StudioOwnerDashboardContent({
    required this.profile,
    required this.location,
    required this.followersCount,
    required this.followingCount,
    required this.photoUploading,
    required this.onBack,
    required this.onMenu,
    required this.onEditPhoto,
    required this.onEditDescription,
    required this.onEditSocialLink,
    required this.contentRevision,
    required this.onManagement,
  });

  @override
  Widget build(BuildContext context) {
    final description = profile.description?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioTopChrome(onBack: onBack, onMenu: onMenu),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudioHeroAvatar(
                imageUrl: profile.profilePictureUrl,
                uploading: photoUploading,
                onEditPhoto: onEditPhoto,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF8C95A3),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFA3ABB8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      StudioProfileWebsiteLink(website: profile.website),
                      const SizedBox(height: 12),
                      _StudioOwnerDescription(
                        description: description,
                        onEdit: onEditDescription,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StudioProfileMetrics(
            followersCount: followersCount,
            followingCount: followingCount,
            roomCount: profile.activeRoomCount,
            backlineCount: profile.backlineUnitCount,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GradientBorderActionButton(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Yönetim Paneli',
                  onPressed: onManagement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StudioOwnerTabs(
            profileId: profile.id,
            timeZone: profile.timeZone,
            contentRevision: contentRevision,
          ),
          const SizedBox(height: 18),
          ProfileSocialLinksRow(
            pillWidth: 74,
            items: studioSocialPlatforms
                .map(
                  (platform) => ProfileSocialLinkItem(
                    platform: platform,
                    url: socialUrlForStudioProfile(profile, platform),
                  ),
                )
                .toList(),
            editable: true,
            onAddLink: onEditSocialLink,
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerDescription extends StatelessWidget {
  final String? description;
  final VoidCallback onEdit;

  const _StudioOwnerDescription({
    required this.description,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final value = description?.trim() ?? '';
    if (value.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            foregroundColor: _roomFormIconColor,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Açıklama ekle',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFC1C8D2),
              fontSize: 12,
              height: 1.42,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Açıklamayı düzenle',
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: Color(0xFF9FA9B8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioProfileMetrics extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;
  final int roomCount;
  final int backlineCount;

  const _StudioProfileMetrics({
    required this.followersCount,
    required this.followingCount,
    required this.roomCount,
    required this.backlineCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StudioMetricCard(
            icon: Icons.meeting_room_outlined,
            value: roomCount.toString(),
            label: 'Oda',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StudioMetricCard(
            icon: Icons.people_outline,
            value: _formatCount(followersCount),
            label: 'Takipçi',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StudioMetricCard(
            icon: Icons.person_add_alt_1_outlined,
            value: _formatCount(followingCount),
            label: 'Takip',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StudioMetricCard(
            icon: Icons.settings_input_component_outlined,
            value: backlineCount.toString(),
            label: 'Backline',
          ),
        ),
      ],
    );
  }

  static String _formatCount(int? value) {
    if (value == null) return '...';
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
      return '${compact.replaceAll('.0', '')}K';
    }
    return value.toString();
  }
}

class _StudioTopChrome extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  const _StudioTopChrome({required this.onBack, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Spacer(),
        Transform.translate(
          offset: const Offset(6, 4),
          child: IconButton(
            onPressed: onMenu,
            icon: const ProfileMenuLogo(),
            tooltip: 'Menü',
          ),
        ),
      ],
    );
  }
}

class _StudioHeroAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onEditPhoto;

  const _StudioHeroAvatar({
    required this.imageUrl,
    required this.uploading,
    required this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = isValidNetworkImageUrl(imageUrl);
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B2CFF).withValues(alpha: 0.22),
                  blurRadius: 18,
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.2),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF070B13),
                child: hasImage
                    ? AppCachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 228,
                        cacheHeight: 228,
                        errorBuilder: (_) => Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/logotransparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/logotransparent.png',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
          if (onEditPhoto != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: uploading ? null : onEditPhoto,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF050910),
                      width: 2,
                    ),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.edit, size: 13, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudioMetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StudioMetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StudioSocialGradientIcon(icon, size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFA0A9B6), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StudioActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool outlined;
  final VoidCallback? onTap;

  const _StudioActionButton({
    required this.icon,
    required this.label,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final innerRadius = BorderRadius.circular(7.3);
    final child = InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: outlined
              ? LinearGradient(colors: AppColors.brandGradient)
              : const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFF7C3AED)],
                ),
        ),
        padding: outlined ? const EdgeInsets.all(0.7) : EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: outlined ? innerRadius : borderRadius,
            color: outlined
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AnimatedOpacity(
      opacity: onTap == null ? 0.58 : 1,
      duration: const Duration(milliseconds: 160),
      child: child,
    );
  }
}

class _StudioSocialGradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _StudioSocialGradientIcon(this.icon, {required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.socialOrange,
          AppColors.socialPink,
          AppColors.socialPurple,
        ],
      ).createShader(bounds),
      child: Icon(icon, size: size, color: AppColors.white),
    );
  }
}

class _StudioOwnerTabs extends StatelessWidget {
  final String profileId;
  final String timeZone;
  final int contentRevision;

  const _StudioOwnerTabs({
    required this.profileId,
    required this.timeZone,
    required this.contentRevision,
  });

  @override
  Widget build(BuildContext context) {
    return _StudioTabsFrame(
      profileId: profileId,
      canReserve: false,
      ownerMode: true,
      phone: null,
      timeZone: timeZone,
      contentRevision: contentRevision,
      onMessage: null,
    );
  }
}

class _StudioTabsFrame extends StatelessWidget {
  final String profileId;
  final bool canReserve;
  final bool ownerMode;
  final String? phone;
  final String timeZone;
  final int contentRevision;
  final VoidCallback? onMessage;

  const _StudioTabsFrame({
    required this.profileId,
    required this.canReserve,
    required this.ownerMode,
    required this.phone,
    required this.timeZone,
    required this.contentRevision,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          labelColor: const Color(0xFFFF8A8A),
          unselectedLabelColor: const Color(0xFFB1B8C4),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: const _StudioTabIndicator(),
          dividerColor: const Color(0xFF151D29),
          tabs: const [
            Tab(text: 'Odalar'),
            Tab(text: 'Kayıtlar'),
            Tab(text: 'Backline'),
          ],
        ),
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return IndexedStack(
              index: controller.index,
              children: [
                _StudioRoomsPanel(
                  profileId: profileId,
                  canReserve: canReserve,
                  ownerMode: ownerMode,
                  timeZone: timeZone,
                  contentRevision: contentRevision,
                ),
                _StudioRecordingsPanel(
                  profileId: profileId,
                  ownerMode: ownerMode,
                  initialSpotifyTracks:
                      context
                          .watch<StudioProfileCubit>()
                          .state
                          .profile
                          ?.spotifyTracks ??
                      const <SpotifyTrackPreview>[],
                ),
                _StudioBacklinePanel(
                  profileId: profileId,
                  ownerMode: ownerMode,
                  phone: phone,
                  contentRevision: contentRevision,
                  onMessage: onMessage,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudioTabIndicator extends Decoration {
  const _StudioTabIndicator();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _StudioTabIndicatorPainter();
  }
}

class _StudioTabIndicatorPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = Rect.fromLTWH(
      offset.dx + 8,
      offset.dy + size.height - 2,
      size.width - 16,
      2,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );
  }
}

const _maximumStudioRoomCount = 10;
