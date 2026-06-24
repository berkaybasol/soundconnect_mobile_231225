part of 'musician_profile_screen.dart';

class _MusicianPublicProfileContent extends StatelessWidget {
  final MusicianProfile profile;
  final ProfileMedia? media;
  final int? followersCount;
  final int? followingCount;
  final List<String>? activeVenues;
  final String viewerUserId;
  final bool isFollowing;
  final bool followLoading;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final VoidCallback? onEditPhoto;
  final bool photoUploading;
  final String? uploadedProfilePhotoUrl;
  final bool socialEditable;
  final ValueChanged<ProfileSocialPlatform>? onAddSocialLink;
  final bool descriptionEditable;
  final Future<void> Function(String)? onSaveDescription;
  final bool ownerMode;
  final VoidCallback? onEditProfilePressed;
  final bool venueEditable;
  final VoidCallback? onEditVenues;

  const _MusicianPublicProfileContent({
    required this.profile,
    required this.media,
    required this.followersCount,
    required this.followingCount,
    required this.activeVenues,
    required this.viewerUserId,
    required this.isFollowing,
    required this.followLoading,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.onEditPhoto,
    required this.photoUploading,
    required this.uploadedProfilePhotoUrl,
    required this.socialEditable,
    required this.onAddSocialLink,
    required this.descriptionEditable,
    required this.onSaveDescription,
    required this.ownerMode,
    required this.onEditProfilePressed,
    required this.venueEditable,
    required this.onEditVenues,
  });

  List<String> _resolveVenues() {
    if (activeVenues != null && activeVenues!.isNotEmpty) {
      return activeVenues!;
    }
    if (profile.activeVenues.isNotEmpty) return profile.activeVenues;
    return const [];
  }

  ProfileMedia _resolveMedia(ProfileMedia? media) {
    if (media != null &&
        (media.featuredVideo != null ||
            media.videos.isNotEmpty ||
            media.audios.isNotEmpty)) {
      return media;
    }
    return const ProfileMedia(featuredVideo: null, videos: [], audios: []);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedMedia = _resolveMedia(media);
    final canFollow =
        viewerUserId.isNotEmpty &&
        profile.userId.isNotEmpty &&
        viewerUserId != profile.userId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: GradientText(
            text: 'SoundConnect',
            gradient: LinearGradient(colors: AppColors.brandGradient),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          leading: const BackButton(),
          centerTitle: true,
          actions: ownerMode
              ? [
                  IconButton(
                    tooltip: 'Menü',
                    onPressed: () => _showOwnerQuickMenu(context),
                    icon: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ]
              : null,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileTopSection(
                header: _ProfileHeader(
                  profile: profile,
                  onEditPhoto: onEditPhoto,
                  uploading: photoUploading,
                  uploadedPhotoUrl: uploadedProfilePhotoUrl,
                ),
                identity: ProfileIdentityHeader(
                  username: profile.username,
                  secondaryText: profile.bands.isNotEmpty
                      ? profile.bands.first
                      : null,
                  fallbackName: 'Kullanıcı',
                ),
                followerSummary: ProfileFollowerSummary(
                  followersCount: followersCount,
                  followingCount: followingCount,
                ),
                actionButtons: ProfileActionButtons(
                  isFollowing: isFollowing,
                  isEnabled: canFollow,
                  isLoading: followLoading,
                  ownerMode: ownerMode,
                  onEditProfilePressed: onEditProfilePressed,
                  onFollowToggle: () {
                    if (!canFollow) return;
                    context.read<FollowActionCubit>().toggleFollow(
                      followerId: viewerUserId,
                      followingId: profile.userId,
                    );
                  },
                ),
                bioSection: EditableBioSection(
                  bio: profile.bio,
                  editable: descriptionEditable,
                  onSave: onSaveDescription,
                  addLabel: 'Kendini birkaç cümleyle anlat',
                  hintText: 'Müziğini, tarzını ve seni anlatan birkaç şey yaz...',
                ),
                afterBio: ownerMode
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: AppColors.brandGradient,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(0.7),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            MusicianManagementPanelScreen(
                                              musicianProfile: profile,
                                              onCreateVenueConnection:
                                                  onEditVenues,
                                            ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.white,
                                    backgroundColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.dashboard_customize_outlined,
                                    color: AppColors.white,
                                  ),
                                  label: const Text(
                                    'Yönetim Paneli',
                                    style: TextStyle(color: AppColors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              ProfileSectionHeader(
                title: 'Çaldığı Mekanlar',
                actionLabel: venueEditable ? 'Düzenle' : 'Tümü',
                actionOnTap: venueEditable ? onEditVenues : null,
              ),
              VenueNameCarousel(
                items: _resolveVenues(),
                editable: venueEditable,
                onAddTap: onEditVenues,
              ),
              const SizedBox(height: 12),
              ProfileMediaTabs(
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.graphic_eq, size: 18),
                        SizedBox(width: 6),
                        Text('Sesler'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline, size: 18),
                        SizedBox(width: 6),
                        Text('Video'),
                      ],
                    ),
                  ),
                ],
              ),
              _MediaContent(
                media: resolvedMedia,
                profileId: profile.id,
                spotifyTracks: spotifyTracks,
                spotifyLoading: spotifyLoading,
                ownerMode: ownerMode,
              ),
              const SizedBox(height: 18),
              ProfileSocialButtonRow(
                profile: profile,
                editable: socialEditable,
                onAddLink: onAddSocialLink,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: ProfileBottomBar(
          profileImageUrl: (uploadedProfilePhotoUrl?.trim().isNotEmpty == true)
              ? uploadedProfilePhotoUrl!.trim()
              : profile.profilePicture,
        ),
      ),
    );
  }
}
