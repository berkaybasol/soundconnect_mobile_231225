part of 'venue_profile_screen.dart';

class _MusicianPublicProfileView extends StatefulWidget {
  const _MusicianPublicProfileView();

  @override
  State<_MusicianPublicProfileView> createState() =>
      _MusicianPublicProfileViewState();
}

class _MusicianPublicProfileViewState
    extends State<_MusicianPublicProfileView> {
  String? _ownerVenueId;
  bool _openIncomingApplicationsOnLoad = false;
  bool _incomingApplicationsOpened = false;
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _profileSearchRepository = serviceLocator<ProfileSearchRepository>();
  final _venueEventRepository = serviceLocator<VenueEventRepository>();
  String? _viewerUserId;
  String? _currentProfileUserId;
  bool _photoUploading = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<WeeklyCalendarEvent> _fallbackWeeklyEvents = const [];
  String? _fallbackWeeklyEventsVenueId;
  bool _loadingFallbackWeeklyEvents = false;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  Future<void> _refreshProfile() async {
    await context.read<VenueProfileCubit>().loadOwner(venueId: _ownerVenueId);
    if (!mounted) return;

    final profile = context.read<VenueProfileCubit>().state.ownerProfile;
    if (profile == null) return;
    _fallbackWeeklyEventsVenueId = null;
    _fallbackWeeklyEvents = const [];
    final refreshes = <Future<void>>[
      context.read<ProfileMediaCubit>().loadMedia(
        profileType: ProfileMediaOwnerType.venue.apiValue,
        profileId: profile.venueProfileId,
      ),
      context.read<FollowCountCubit>().loadCounts(profile.ownerUserId),
    ];
    if (profile.weeklyEvents.isEmpty) {
      refreshes.add(_ensureFallbackWeeklyEvents(profile));
    }
    await Future.wait<void>(refreshes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ownerVenueId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is VenueProfileArgs) {
        _ownerVenueId = args.venueId;
        _openIncomingApplicationsOnLoad = args.openIncomingApplications;
      } else if (args is String) {
        _ownerVenueId = args;
      } else if (args is Map<String, dynamic>) {
        _ownerVenueId = args['venueId']?.toString();
        _openIncomingApplicationsOnLoad =
            args['openIncomingApplications'] == true;
      }
      context.read<VenueProfileCubit>().loadOwner(venueId: _ownerVenueId);
    }
    if (_viewerUserId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is VenueProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is PublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is Map<String, dynamic>) {
      _viewerUserId = args['viewerUserId']?.toString();
    } else if (args is String) {
      _viewerUserId = args;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenueProfileCubit, VenueProfileState>(
      builder: (context, venueState) {
        final ownerProfile = venueState.ownerProfile;
        if (venueState.status == VenueProfileStatus.loading &&
            ownerProfile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (ownerProfile == null) {
          return Scaffold(
            body: Center(
              child: Text(
                venueState.error?.message ?? 'Venue profili getirilemedi',
              ),
            ),
          );
        }
        _scheduleIncomingApplicationsSheet(ownerProfile);
        final profile = _toDisplayProfile(ownerProfile);
        final primaryWeeklyEvents = _toWeeklyCalendarEvents(ownerProfile);
        if (primaryWeeklyEvents.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureFallbackWeeklyEvents(ownerProfile);
          });
        }
        final weeklyEvents = primaryWeeklyEvents.isNotEmpty
            ? primaryWeeklyEvents
            : _fallbackWeeklyEvents;
        _currentProfileUserId = ownerProfile.ownerUserId;
        _loadCoordinator.scheduleMediaLoad(
          context,
          mounted: mounted,
          profileId: ownerProfile.venueProfileId,
          profileType: ProfileMediaOwnerType.venue,
        );
        _loadCoordinator.scheduleFollowCountsLoad(
          context,
          mounted: mounted,
          userId: ownerProfile.ownerUserId,
        );
        final viewerUserId = _viewerUserId ?? '';
        _loadCoordinator.scheduleFollowStatusLoad(
          context,
          mounted: mounted,
          followerId: viewerUserId,
          followingId: ownerProfile.ownerUserId,
        );
        return MultiBlocListener(
          listeners: [
            BlocListener<FollowActionCubit, FollowActionState>(
              listener: (context, state) {
                if (state.status == FollowActionStatus.success &&
                    _currentProfileUserId != null) {
                  context.read<FollowCountCubit>().loadCounts(
                    _currentProfileUserId!,
                  );
                }
              },
            ),
          ],
          child: Builder(
            builder: (context) {
              final media = context.watch<ProfileMediaCubit>().state.media;
              final followState = context.watch<FollowCountCubit>().state;
              final followersCount =
                  followState.status == FollowCountStatus.loading
                  ? null
                  : followState.followersCount;
              final followingCount =
                  followState.status == FollowCountStatus.loading
                  ? null
                  : followState.followingCount;
              final actionState = context.watch<FollowActionCubit>().state;
              return _MusicianPublicProfileContent(
                profile: profile,
                media: media,
                followersCount: followersCount,
                followingCount: followingCount,
                activeVenues: ownerProfile.activeMusicians,
                activeBands: ownerProfile.activeBands,
                viewerUserId: '',
                isFollowing: actionState.isFollowing,
                followLoading: actionState.status == FollowActionStatus.loading,
                spotifyTracks: const [],
                spotifyLoading: false,
                onEditPhoto: () => _editProfilePhoto(ownerProfile),
                photoUploading: _photoUploading,
                uploadedProfilePhotoUrl: ownerProfile.profilePictureUrl,
                socialEditable: false,
                onAddSocialLink: null,
                descriptionEditable: false,
                onSaveDescription: null,
                ownerMode: true,
                onEditProfilePressed: _onEditProfilePressed,
                venueEditable: false,
                onEditVenues: null,
                onEditEvents: () => _editConnectedArtists(ownerProfile.venueId),
                weeklyEvents: weeklyEvents,
                galleryOwnerId: ownerProfile.venueProfileId,
                onRefresh: _refreshProfile,
              );
            },
          ),
        );
      },
    );
  }

  void _scheduleIncomingApplicationsSheet(VenueOwnerProfile ownerProfile) {
    if (!_openIncomingApplicationsOnLoad || _incomingApplicationsOpened) return;
    _incomingApplicationsOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.navBlueDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => VenueApplicationsSheet(
          venueId: ownerProfile.venueId,
          mode: ApplicationListMode.incoming,
        ),
      );
    });
  }
}
