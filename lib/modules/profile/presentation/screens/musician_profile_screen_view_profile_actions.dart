part of 'musician_profile_screen.dart';

extension _MusicianProfileViewStateProfileActions
    on _MusicianPublicProfileViewState {
  Future<void> _editProfilePhoto(MusicianProfile profile) async {
    _updateState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: profile.id,
      );
      if (uploaded == null) return;
      if (!mounted) return;
      await context.read<MusicianProfileCubit>().updateProfile(
        MusicianProfileSaveRequest(profilePicture: uploaded.assetId),
      );
      _updateState(() {
        _uploadedProfilePhotoUrl = uploaded.preferredUrl;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf yüklenemedi: $e')));
    } finally {
      if (mounted) {
        _updateState(() => _photoUploading = false);
      }
    }
  }

  String? _socialUrlFor(
    MusicianProfile profile,
    ProfileSocialPlatform platform,
  ) => socialUrlForMusicianProfile(profile, platform);

  Future<void> _addSocialLink(
    MusicianProfile profile,
    ProfileSocialPlatform platform,
  ) async {
    final normalized = await promptForSocialLink(
      context,
      platform: platform,
      initialValue: _socialUrlFor(profile, platform)?.trim() ?? '',
    );
    if (normalized == null) return;
    if (!mounted) return;

    try {
      await context.read<MusicianProfileCubit>().updateProfile(
        buildMusicianSocialLinkRequest(platform, normalized),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${platform.label} eklendi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sosyal link kaydedilemedi')),
      );
    }
  }

  Future<void> _saveDescription(String value) async {
    final normalized = value.trim();
    try {
      await context.read<MusicianProfileCubit>().updateProfile(
        MusicianProfileSaveRequest(description: normalized),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Açıklama güncellendi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Açıklama kaydedilemedi')));
    }
  }

  void _onEditProfilePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aşağıdaki alanlardan profilini düzenleyebilirsin.'),
      ),
    );
  }

  Future<List<VenueOption>> _fetchAllVenues() async {
    final result = await _venueDirectoryRepository.getAllVenues();
    return result.data ?? const [];
  }

  Future<List<VenueLookupOption>> _fetchCities() async {
    final result = await _locationRepository.getCities();
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchNeighborhoods(String districtId) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueConnection>> _fetchVenueConnectionsByStatus(
    String profileId, {
    required String status,
  }) async {
    final result = await _artistVenueRepository.getVenueConnectionsByStatus(
      profileId,
      status: status,
    );
    return result.data ?? const [];
  }

  Future<List<VenueConnection>> _fetchAcceptedVenueConnections(
    String profileId,
  ) {
    return _fetchVenueConnectionsByStatus(profileId, status: 'ACCEPTED');
  }

  Future<List<VenueConnection>> _fetchPendingVenueConnections(
    String profileId,
  ) {
    return _fetchVenueConnectionsByStatus(profileId, status: 'PENDING');
  }
}
