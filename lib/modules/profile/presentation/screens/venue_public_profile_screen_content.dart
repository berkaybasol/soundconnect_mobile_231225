part of 'venue_public_profile_screen.dart';

class _MusicianPublicProfileContent extends StatelessWidget {
  final MusicianProfile profile;
  final String galleryOwnerId;
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
  final List<WeeklyCalendarEvent> weeklyEvents;

  const _MusicianPublicProfileContent({
    required this.profile,
    required this.galleryOwnerId,
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
    required this.weeklyEvents,
  });

  List<VenueActiveMusician> _resolveVenues() {
    final List<VenueActiveMusician> items = <VenueActiveMusician>[
      ...(activeVenues ?? const <VenueActiveMusician>[]),
      ...(activeBands ?? const <VenueActiveBand>[]).map(
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
          title: const GradientText(
            text: 'SoundConnect',
            gradient: LinearGradient(colors: AppColors.brandGradient),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          leading: const BackButton(),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: _ProfileHeader(profile: profile),
              ),
              const SizedBox(height: 16),
              _ProfileIdentity(profile: profile),
              const SizedBox(height: 14),
              _FollowerRow(
                followersCount: followersCount,
                followingCount: followingCount,
              ),
              const SizedBox(height: 12),
              _ActionButtons(
                isFollowing: isFollowing,
                isEnabled: canFollow,
                isLoading: followLoading,
                onMessageTap: () {
                  if (profile.userId.trim().isEmpty) return;
                  final username = (profile.username ?? '').trim();
                  Navigator.of(context).pushNamed(
                    AppRoutes.dmChat,
                    arguments: DmChatScreenArgs(
                      otherUserId: profile.userId,
                      otherUsername: username.isNotEmpty ? username : null,
                      otherUserProfilePicture: profile.profilePicture,
                      currentUserId: viewerUserId,
                    ),
                  );
                },
                onFollowToggle: () {
                  if (!canFollow) return;
                  context.read<FollowActionCubit>().toggleFollow(
                    followerId: viewerUserId,
                    followingId: profile.userId,
                  );
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  profile.bio?.trim().isNotEmpty == true
                      ? profile.bio!
                      : 'Henuz bir aciklama eklenmedi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionHeader(title: 'Haftalik Takvim'),
              WeeklyEventCarousel(items: weeklyEvents, compactTitle: true),
              const SizedBox(height: 12),
              const _SectionHeader(
                title: 'Aktif Sanatcilar',
                actionLabel: 'Tumu',
              ),
              _ActiveMusicianCarousel(items: _resolveVenues()),
              const SizedBox(height: 12),
              _MediaTabs(),
              _MediaContent(
                media: resolvedMedia,
                galleryOwnerId: galleryOwnerId,
                spotifyTracks: const [],
                spotifyLoading: spotifyLoading,
              ),
              const SizedBox(height: 18),
              _SocialButtonRow(profile: profile),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: const ProfilePublicBottomBar(),
      ),
    );
  }
}
