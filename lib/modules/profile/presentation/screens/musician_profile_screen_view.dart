part of 'musician_profile_screen.dart';

class _MusicianPublicProfileView extends StatefulWidget {
  const _MusicianPublicProfileView();

  @override
  State<_MusicianPublicProfileView> createState() =>
      _MusicianPublicProfileViewState();
}

class _MusicianPublicProfileViewState
    extends State<_MusicianPublicProfileView> {
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _locationRepository = serviceLocator<LocationRepository>();
  final _venueDirectoryRepository = serviceLocator<VenueDirectoryRepository>();
  String? _viewerUserId;
  String? _currentProfileUserId;
  bool _photoUploading = false;
  String? _uploadedProfilePhotoUrl;
  final ImagePicker _imagePicker = ImagePicker();
  bool _openManagementPanelOnLoad = false;
  bool _managementPanelOpened = false;
  bool _openIncomingVenueApplicationsOnLoad = false;
  bool _incomingVenueApplicationsOpened = false;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  Future<void> _refreshProfile() async {
    await context.read<MusicianProfileCubit>().loadMyProfile();
    if (!mounted) return;

    final profile = context.read<MusicianProfileCubit>().state.profile;
    if (profile == null) return;
    await Future.wait<void>([
      context.read<ProfileMediaCubit>().loadMedia(
        profileType: ProfileMediaOwnerType.musician.apiValue,
        profileId: profile.id,
      ),
      context.read<FollowCountCubit>().loadCounts(profile.userId),
      context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(
        profile.id,
      ),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewerUserId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is MusicianProfileScreenArgs) {
      _openManagementPanelOnLoad = args.openManagementPanel;
      _openIncomingVenueApplicationsOnLoad = args.openIncomingVenueApplications;
    } else if (args is PublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is Map<String, dynamic>) {
      _viewerUserId = args['viewerUserId']?.toString();
      _openManagementPanelOnLoad = args['openManagementPanel'] == true;
      _openIncomingVenueApplicationsOnLoad =
          args['openIncomingVenueApplications'] == true;
    } else if (args is String) {
      _viewerUserId = args;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: BlocBuilder<MusicianProfileCubit, MusicianProfileState>(
        builder: (context, state) {
          final isInitialLoading =
              state.status == MusicianProfileStatus.loading &&
              state.profile == null;
          if (isInitialLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.profile == null) {
            return Scaffold(
              body: Center(
                child: Text(state.error?.message ?? 'Profil getirilemedi'),
              ),
            );
          }

          final profile = state.profile!;
          _scheduleIncomingVenueApplicationsSheet(profile);
          _openManagementPanelAfterLoad(profile);
          _currentProfileUserId = profile.userId;
          _loadCoordinator.scheduleMediaLoad(
            context,
            mounted: mounted,
            profileId: profile.id,
            profileType: ProfileMediaOwnerType.musician,
          );
          _loadCoordinator.scheduleFollowCountsLoad(
            context,
            mounted: mounted,
            userId: profile.userId,
          );
          _loadCoordinator.scheduleAcceptedVenuesLoad(
            context,
            mounted: mounted,
            profileId: profile.id,
          );
          final viewerUserId = _viewerUserId ?? '';
          _loadCoordinator.scheduleFollowStatusLoad(
            context,
            mounted: mounted,
            followerId: viewerUserId,
            followingId: profile.userId,
          );
          final media = context.watch<ProfileMediaCubit>().state.media;
          final venueState = context.watch<ArtistVenueConnectionsCubit>().state;
          final venueItems =
              venueState.status == ArtistVenueConnectionsStatus.loading
              ? null
              : venueState.venues;
          final followState = context.watch<FollowCountCubit>().state;
          final followersCount = followState.status == FollowCountStatus.loading
              ? null
              : followState.followersCount;
          final followingCount = followState.status == FollowCountStatus.loading
              ? null
              : followState.followingCount;
          final actionState = context.watch<FollowActionCubit>().state;
          return _MusicianPublicProfileContent(
            profile: profile,
            media: media,
            followersCount: followersCount,
            followingCount: followingCount,
            activeVenues: venueItems,
            viewerUserId: viewerUserId,
            isFollowing: actionState.isFollowing,
            followLoading: actionState.status == FollowActionStatus.loading,
            spotifyTracks: profile.spotifyTracks,
            spotifyLoading: false,
            onEditPhoto: () => _editProfilePhoto(profile),
            photoUploading: _photoUploading,
            uploadedProfilePhotoUrl: _uploadedProfilePhotoUrl,
            socialEditable: true,
            onAddSocialLink: (platform) => _addSocialLink(profile, platform),
            descriptionEditable: true,
            onSaveDescription: _saveDescription,
            ownerMode: true,
            onEditProfilePressed: _onEditProfilePressed,
            venueEditable: true,
            onEditVenues: () => _editVenues(profile.id),
            onRefresh: _refreshProfile,
          );
        },
      ),
    );
  }

  void _openManagementPanelAfterLoad(MusicianProfile profile) {
    if (!_openManagementPanelOnLoad || _managementPanelOpened) return;
    _managementPanelOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MusicianManagementPanelScreen(
            musicianProfile: profile,
            onCreateVenueConnection: () => _editVenues(profile.id),
          ),
        ),
      );
    });
  }

  void _scheduleIncomingVenueApplicationsSheet(MusicianProfile profile) {
    if (!_openIncomingVenueApplicationsOnLoad ||
        _incomingVenueApplicationsOpened) {
      return;
    }
    _incomingVenueApplicationsOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showMusicianVenueApplicationList(
        context: context,
        musicianProfileId: profile.id,
        mode: _MusicianVenueApplicationListMode.incoming,
      );
    });
  }
}
