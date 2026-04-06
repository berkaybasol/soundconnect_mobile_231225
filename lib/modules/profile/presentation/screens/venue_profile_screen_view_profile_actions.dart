// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously, invalid_use_of_protected_member

part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateProfileActions on _MusicianPublicProfileViewState {
  Future<void> _editProfilePhoto(VenueOwnerProfile profile) async {
    setState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'VENUE_PROFILE',
        ownerId: profile.venueProfileId,
      );
      if (uploaded == null) return;
      await context.read<VenueProfileCubit>().updateOwnerProfile(
        VenueProfileSaveRequest(profilePicture: uploaded.assetId),
        venueId: profile.venueId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotografi guncellendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotograf yuklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _photoUploading = false);
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

    try {
      final venueRequest = switch (platform) {
        ProfileSocialPlatform.instagram => VenueProfileSaveRequest(
          instagramUrl: normalized,
        ),
        ProfileSocialPlatform.youtube => VenueProfileSaveRequest(
          youtubeUrl: normalized,
        ),
        ProfileSocialPlatform.soundcloud => VenueProfileSaveRequest(
          websiteUrl: normalized,
        ),
        ProfileSocialPlatform.spotify => VenueProfileSaveRequest(
          websiteUrl: normalized,
        ),
      };
      await context.read<VenueProfileCubit>().updateOwnerProfile(
        venueRequest,
        venueId: profile.id,
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
      final ownerProfile = context.read<VenueProfileCubit>().state.ownerProfile;
      if (ownerProfile == null) return;
      await context.read<VenueProfileCubit>().updateOwnerProfile(
        VenueProfileSaveRequest(bio: normalized),
        venueId: ownerProfile.venueId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aciklama guncellendi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aciklama kaydedilemedi')));
    }
  }

  void _onEditProfilePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Asagidaki alanlardan profilini duzenleyebilirsin.'),
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

  Future<List<MusicianConnection>> _fetchArtistConnectionsByStatus(
    String venueId, {
    required String status,
  }) async {
    final result = await _artistVenueRepository.getMusicianConnectionsByStatus(
      venueId,
      status: status,
    );
    return result.data ?? const [];
  }

}
