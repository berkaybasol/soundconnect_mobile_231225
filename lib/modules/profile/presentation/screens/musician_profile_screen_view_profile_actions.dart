part of 'musician_profile_screen.dart';

extension _MusicianProfileViewStateProfileActions
    on _MusicianPublicProfileViewState {
  Future<void> _editProfilePhoto(MusicianProfile profile) async {
    final session = _profileActionSession;
    bool current() =>
        mounted && session.isCurrent && profile.userId == session.userId;
    if (_photoUploading || !current()) return;
    _updateState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: profile.id,
        isCurrent: current,
      );
      if (uploaded == null) return;
      if (!mounted || !current()) return;
      final result = await context.read<MusicianProfileCubit>().updateProfile(
        MusicianProfileSaveRequest(profilePicture: uploaded.assetId),
        expectedSessionKey: session.userId,
      );
      if (!mounted || !current()) return;
      if (!result.isSuccess) {
        throw result.error?.message ?? 'Profil fotoğrafı kaydedilemedi.';
      }
      _updateState(() {
        _uploadedProfilePhotoUrl = uploaded.preferredUrl;
      });
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Profil fotoğrafı güncellendi'),
        ),
      );
    } catch (e) {
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('Fotoğraf yüklenemedi: $e'),
        ),
      );
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
    final session = _profileActionSession;
    bool current() =>
        mounted && session.isCurrent && profile.userId == session.userId;
    if (!mounted || !current()) return;
    final normalized = await promptForSocialLink(
      context,
      platform: platform,
      initialValue: _socialUrlFor(profile, platform)?.trim() ?? '',
    );
    if (normalized == null) return;
    if (!mounted || !current()) return;

    try {
      final result = await context.read<MusicianProfileCubit>().updateProfile(
        buildMusicianSocialLinkRequest(platform, normalized),
        expectedSessionKey: session.userId,
      );
      if (!mounted || !current()) return;
      if (!result.isSuccess) {
        throw result.error?.message ?? 'Sosyal link kaydedilemedi';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: Text('${platform.label} eklendi'),
        ),
      );
    } catch (_) {
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Sosyal link kaydedilemedi'),
        ),
      );
    }
  }

  Future<bool> _saveDescription(String value) async {
    final session = _profileActionSession;
    bool current() => mounted && session.isCurrent;
    if (!current()) return false;
    final normalized = value.trim();
    try {
      final result = await context.read<MusicianProfileCubit>().updateProfile(
        MusicianProfileSaveRequest(description: normalized),
        expectedSessionKey: session.userId,
      );
      if (!mounted || !current()) return false;
      if (!result.isSuccess) {
        throw result.error?.message ?? 'Açıklama kaydedilemedi';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Açıklama güncellendi'),
        ),
      );
      return true;
    } catch (_) {
      if (!mounted || !current()) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Açıklama kaydedilemedi'),
        ),
      );
      return false;
    }
  }

  void _onEditProfilePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.info,
        content: const Text(
          'Aşağıdaki alanlardan profilini düzenleyebilirsin.',
        ),
      ),
    );
  }

  Future<List<VenueOption>> _fetchAllVenues() async {
    final result = await _venueDirectoryRepository.getAllVenues();
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Mekanlar getirilemedi.';
    }
    return result.data ?? const [];
  }

  Future<List<VenueLookupOption>> _fetchCities() async {
    final result = await _locationRepository.getCities();
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Şehirler getirilemedi.';
    }
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'İlçeler getirilemedi.';
    }
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchNeighborhoods(String districtId) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Semtler getirilemedi.';
    }
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
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Mekan bağlantıları getirilemedi.';
    }
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
