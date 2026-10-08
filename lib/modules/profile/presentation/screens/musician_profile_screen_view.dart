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
  final _profileActionSession = ProfileActionSession(
    roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
  );
  String? _uploadedProfilePhotoUrl;
  final ImagePicker _imagePicker = ImagePicker();
  bool _openManagementPanelOnLoad = false;
  bool _managementPanelOpened = false;
  String? _completionTaskCodeOnLoad;
  bool _completionTaskOpened = false;
  bool _openIncomingVenueApplicationsOnLoad = false;
  bool _incomingVenueApplicationsOpened = false;
  bool _initialLoadStarted = false;

  bool get _canPresent =>
      mounted &&
      _profileActionSession.isCurrent &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _loadProfile() async {
    if (!_canPresent) return;
    await context.read<MusicianProfileCubit>().loadMyProfile(
      canPresent: () => _canPresent,
      admitContent: NotificationTargetRead.beginFollowRequest(context),
    );
  }

  Future<void> _showUnavailableProfileMenu() async {
    if (!_canPresent) return;
    await showProfileQuickMenu(
      context,
      settingsTileKey: const Key('musician-account-settings'),
      onSettings: () async {
        if (!_canPresent) return;
        await Navigator.of(context).pushNamed(AppRoutes.settings);
      },
    );
  }

  Widget _unavailableProfile(MusicianProfileState state) {
    final current = _profileActionSession.isCurrent;
    final loading = state.status == MusicianProfileStatus.loading;
    return Scaffold(
      appBar: AppBar(
        title: const ProfileBrandTitle(),
        centerTitle: true,
        actions: current
            ? [
                IconButton(
                  tooltip: 'Menü',
                  onPressed: _showUnavailableProfileMenu,
                  icon: const ProfileMenuLogo(),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: loading && current
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current
                          ? state.error?.message ?? 'Profil getirilemedi'
                          : 'Oturum değişti. Profili yeniden aç.',
                      textAlign: TextAlign.center,
                    ),
                    if (current) ...[
                      const SizedBox(height: 16),
                      GradientOutlineButton(
                        label: 'Tekrar dene',
                        onPressed: _loadProfile,
                      ),
                    ],
                  ],
                ),
        ),
      ),
      bottomNavigationBar: current ? ProfileBottomBar() : null,
    );
  }

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  Future<void> _refreshProfile() async {
    await _loadProfile();
    if (!mounted || !_canPresent) return;

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
      _completionTaskCodeOnLoad = args.completionTaskCode?.trim().toUpperCase();
    } else if (args is PublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is Map<String, dynamic>) {
      _viewerUserId = args['viewerUserId']?.toString();
      _openManagementPanelOnLoad = args['openManagementPanel'] == true;
      _openIncomingVenueApplicationsOnLoad =
          args['openIncomingVenueApplications'] == true;
      _completionTaskCodeOnLoad = args['completionTaskCode']
          ?.toString()
          .trim()
          .toUpperCase();
    } else if (args is String) {
      _viewerUserId = args;
    }
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      unawaited(_loadProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
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
          if (state.profile == null || !_profileActionSession.isCurrent) {
            return _unavailableProfile(state);
          }

          final profile = state.profile!;
          _scheduleIncomingVenueApplicationsSheet(profile);
          _openCompletionTaskAfterLoad(profile);
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
              venueState.status == ArtistVenueConnectionsStatus.success
              ? venueState.venues
              : null;
          final followState = context.watch<FollowCountCubit>().state;
          final followersCount = followState.status == FollowCountStatus.loading
              ? null
              : followState.followersCount;
          final followingCount = followState.status == FollowCountStatus.loading
              ? null
              : followState.followingCount;
          final actionState = context.watch<FollowActionCubit>().state;
          return NotificationTargetReady(
            contentIdentity: profile,
            ready:
                state.status == MusicianProfileStatus.success &&
                _profileActionSession.isCurrent &&
                !_openIncomingVenueApplicationsOnLoad &&
                !_openManagementPanelOnLoad &&
                !_hasDirectCompletionEditor,
            child: _MusicianPublicProfileContent(
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
            ),
          );
        },
      ),
    );
  }

  void _openManagementPanelAfterLoad(MusicianProfile profile) {
    if (!_openManagementPanelOnLoad ||
        _managementPanelOpened ||
        _hasDirectCompletionEditor) {
      return;
    }
    _managementPanelOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_canPresent) return;
      final session = ProfileActionSession(
        roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
      );
      if (!session.isCurrent) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MusicianManagementPanelScreen(
            musicianProfile: profile,
            onCreateVenueConnection: () => _editVenues(profile.id),
          ),
        ),
      );
      if (mounted && session.isCurrent) await _refreshProfile();
    });
  }

  bool get _hasDirectCompletionEditor =>
      musicianProfileCompletionEditorForCode(_completionTaskCodeOnLoad) != null;

  void _openCompletionTaskAfterLoad(MusicianProfile profile) {
    final completionEditor = musicianProfileCompletionEditorForCode(
      _completionTaskCodeOnLoad,
    );
    if (completionEditor == null || _completionTaskOpened) return;
    _completionTaskOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_canPresent) return;
      final session = ProfileActionSession(
        roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
      );
      if (!session.isCurrent) return;
      var refreshAfterEditor = false;
      switch (completionEditor) {
        case MusicianProfileCompletionEditor.instruments:
          refreshAfterEditor = await showMusicianInstrumentEditor(
            context,
            profile: profile,
          );
        case MusicianProfileCompletionEditor.profileDetails:
          refreshAfterEditor = await showMusicianProfileDetailsEditor(
            context,
            profile: profile,
          );
        case MusicianProfileCompletionEditor.portfolio:
          await showMusicianPortfolioCompletionEditor(
            context,
            profile: profile,
          );
          refreshAfterEditor = true;
        case MusicianProfileCompletionEditor.photoAndSocialLinks:
          await showMusicianPhotoAndSocialLinksCompletionEditor(
            context,
            profile: profile,
            onEditPhoto: () => _editProfilePhoto(profile),
            onEditSocialLink: (platform) => _addSocialLink(profile, platform),
          );
          refreshAfterEditor = true;
      }
      if (refreshAfterEditor && mounted && session.isCurrent) {
        await _refreshProfile();
      }
    });
  }

  void _scheduleIncomingVenueApplicationsSheet(MusicianProfile profile) {
    if (!_openIncomingVenueApplicationsOnLoad ||
        _incomingVenueApplicationsOpened) {
      return;
    }
    _incomingVenueApplicationsOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_canPresent) return;
      final session = ProfileActionSession(
        roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
      );
      if (!session.isCurrent) return;
      await _showMusicianVenueApplicationList(
        context: context,
        musicianProfileId: profile.id,
        mode: _MusicianVenueApplicationListMode.incoming,
        forwardNotificationRead: true,
      );
      if (mounted && session.isCurrent) await _refreshProfile();
    });
  }
}
