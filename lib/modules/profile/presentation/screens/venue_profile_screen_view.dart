// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

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
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _locationRepository = serviceLocator<LocationRepository>();
  final _musicianSearchRepository = serviceLocator<MusicianSearchRepository>();
  final _venueDirectoryRepository = serviceLocator<VenueDirectoryRepository>();
  final _venueEventRepository = serviceLocator<VenueEventRepository>();
  String? _viewerUserId;
  String? _currentProfileUserId;
  bool _photoUploading = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<WeeklyCalendarEvent> _fallbackWeeklyEvents = const [];
  String? _fallbackWeeklyEventsVenueId;
  bool _loadingFallbackWeeklyEvents = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ownerVenueId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is VenueProfileArgs) {
        _ownerVenueId = args.venueId;
      } else if (args is String) {
        _ownerVenueId = args;
      }
      context.read<VenueProfileCubit>().loadOwner(venueId: _ownerVenueId);
    }
    if (_viewerUserId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is PublicProfileArgs) {
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
              );
            },
          ),
        );
      },
    );
  }

}

