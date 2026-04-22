part of 'venue_profile_screen.dart';

class _MusicianPublicProfileContent extends StatelessWidget {
  final MusicianProfile profile;
  final ProfileMedia? media;
  final int? followersCount;
  final int? followingCount;
  final List<VenueActiveMusician>? activeVenues;
  final List<VenueActiveBand>? activeBands;
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
  final Future<void> Function()? onEditEvents;
  final List<WeeklyCalendarEvent> weeklyEvents;
  final String galleryOwnerId;

  _MusicianPublicProfileContent({
    required this.profile,
    required this.media,
    required this.followersCount,
    required this.followingCount,
    required this.activeVenues,
    required this.activeBands,
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
    required this.onEditEvents,
    required this.weeklyEvents,
    required this.galleryOwnerId,
  });

  List<VenueActiveMusician> _resolveVenues() {
    final List<VenueActiveMusician> items = <VenueActiveMusician>[
      ...(activeVenues ?? <VenueActiveMusician>[]),
      ...(activeBands ?? <VenueActiveBand>[]).map(
        (band) => VenueActiveMusician(
          musicianProfileId: '',
          bandId: band.bandId,
          displayName: band.displayName,
          profileImageUrl: band.profileImageUrl,
        ),
      ),
    ];
    if (items.isNotEmpty) return items;
    if (profile.activeVenues.isNotEmpty) {
      return profile.activeVenues
          .map(
            (item) => VenueActiveMusician(
              musicianProfileId: '',
              displayName: item,
              profileImageUrl: null,
            ),
          )
          .toList();
    }
    return [];
  }

  ProfileMedia _resolveMedia(ProfileMedia? media) {
    if (media != null &&
        (media.featuredVideo != null ||
            media.videos.isNotEmpty ||
            media.audios.isNotEmpty)) {
      return media;
    }
    return ProfileMedia(featuredVideo: null, videos: [], audios: []);
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          leading: BackButton(),
          centerTitle: true,
          actions: ownerMode
              ? [
                  IconButton(
                    tooltip: 'Menu',
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
                  fallbackName: 'Kullanici',
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
                ),
                afterBio: ownerMode
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: AppColors.brandGradient,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(0.7),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _openVenueManagementPanel(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.white,
                                    backgroundColor: Colors.transparent,
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.dashboard_customize_outlined,
                                    color: AppColors.white,
                                  ),
                                  label: Text(
                                    'Yonetim Paneli',
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
              SizedBox(height: 18),
              ProfileSectionHeader(title: 'Haftalik Takvim'),
              WeeklyEventCarousel(items: weeklyEvents),
              SizedBox(height: 12),
              ProfileSectionHeader(
                title: 'Aktif Sanatcilar',
                actionLabel: venueEditable ? 'Duzenle' : 'Tumu',
                actionOnTap: venueEditable ? onEditVenues : null,
              ),
              ActiveMusicianCarousel(
                items: _resolveVenues(),
                editable: venueEditable,
                onAddTap: onEditVenues,
              ),
              SizedBox(height: 12),
              ProfileMediaTabs(
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 18),
                        SizedBox(width: 6),
                        Text('Fotograflar'),
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
                galleryOwnerId: galleryOwnerId,
                spotifyTracks: [],
                spotifyLoading: spotifyLoading,
                ownerMode: ownerMode,
              ),
              SizedBox(height: 18),
              ProfileSocialButtonRow(
                pillWidth: 74,
                profile: profile,
                editable: socialEditable,
                onAddLink: onAddSocialLink,
              ),
              SizedBox(height: 24),
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
