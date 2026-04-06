part of 'band_profile_screen.dart';

extension _BandProfileViewStateActions on _BandProfileViewState {
  Future<void> _loadBandProfile() async {
    final bandId = _bandId;
    if (bandId == null || bandId.isEmpty) return;

    _updateState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _bandRepository.getBandById(bandId);

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      _updateState(() {
        _loading = false;
        _errorText = result.error?.message ?? 'Band profili getirilemedi.';
      });
      return;
    }

    _updateState(() {
      _loading = false;
      _profile = result.data;
    });

    await _loadFollowersCount(result.data!.id);
    await _loadSpotifyCatalog(result.data!);
    if (!mounted) return;
    await context.read<ProfileMediaCubit>().loadMedia(
      profileType: 'BAND',
      profileId: result.data!.id,
    );
  }

  Future<void> _loadSpotifyCatalog(BandProfile profile) async {
    final trackIds = profile.spotifyTrackIds;
    if (trackIds.isEmpty) {
      if (!mounted) return;
      _updateState(() {
        _spotifyLoading = false;
        _spotifyTracks = const [];
      });
      return;
    }

    _updateState(() => _spotifyLoading = true);
    final result = await _spotifyRepository.getTracksByIds(trackIds);
    if (!mounted) return;

    _updateState(() {
      _spotifyLoading = false;
      _spotifyTracks = result.isSuccess && result.data != null
          ? result.data!
          : const [];
    });
  }

  Future<void> _loadFollowersCount(String bandId) async {
    final result = await _bandFollowRepository.getFollowersCount(bandId);
    if (!mounted) return;
    _updateState(() {
      _followersCount = result.data;
    });
  }

  Future<bool> _saveSpotifyTracks(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  }) async {
    final profile = _profile;
    if (profile == null) return false;

    final result = await _bandRepository.updateBand(
      bandId: profile.id,
      spotifyTrackIds: nextTracks.map((track) => track.id).toList(),
    );

    if (!mounted) return false;

    if (!result.isSuccess || result.data == null) {
      final message = result.error?.message ?? failureMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }

    _updateState(() {
      _profile = result.data;
      _spotifyTracks = nextTracks;
    });
    return true;
  }

  Future<void> _saveDescription(String value) async {
    final profile = _profile;
    if (profile == null) return;

    final result = await _bandRepository.updateBand(
      bandId: profile.id,
      description: value.trim(),
    );

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error?.message ?? 'Aciklama kaydedilemedi.'),
        ),
      );
      return;
    }

    _updateState(() {
      _profile = result.data;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Aciklama guncellendi.')));
  }

  Future<void> _editProfilePhoto() async {
    final profile = _profile;
    if (profile == null) return;

    _updateState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'BAND',
        ownerId: profile.id,
      );
      if (uploaded == null) return;

      final result = await _bandRepository.updateBand(
        bandId: profile.id,
        profilePicture: uploaded.assetId,
      );

      if (!mounted) return;

      if (!result.isSuccess || result.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error?.message ?? 'Profil fotografi guncellenemedi.',
            ),
          ),
        );
        return;
      }

      _updateState(() {
        _profile = result.data;
        _uploadedProfilePhotoUrl = uploaded.preferredUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotografi guncellendi.')),
      );
    } finally {
      if (mounted) {
        _updateState(() => _photoUploading = false);
      }
    }
  }

  Future<void> _addSocialLink(ProfileSocialPlatform platform) async {
    final profile = _profile;
    if (profile == null) return;

    final normalized = await promptForSocialLink(
      context,
      platform: platform,
      initialValue: _socialUrlFor(profile, platform)?.trim() ?? '',
    );
    if (normalized == null) return;

    final result = await _bandRepository.updateBand(
      bandId: profile.id,
      instagramUrl: platform == ProfileSocialPlatform.instagram
          ? normalized
          : null,
      youtubeUrl: platform == ProfileSocialPlatform.youtube ? normalized : null,
      soundCloudUrl: platform == ProfileSocialPlatform.soundcloud
          ? normalized
          : null,
      spotifyEmbedUrl: platform == ProfileSocialPlatform.spotify
          ? normalized
          : null,
    );

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error?.message ?? 'Sosyal link kaydedilemedi.'),
        ),
      );
      return;
    }

    _updateState(() {
      _profile = result.data;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${platform.label} guncellendi.')));
  }

  Future<void> _openBandManagementPanel(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BandManagementPanelScreen(profile: profile),
      ),
    );
  }

  String? _socialUrlFor(BandProfile profile, ProfileSocialPlatform platform) {
    switch (platform) {
      case ProfileSocialPlatform.soundcloud:
        return profile.soundCloudUrl;
      case ProfileSocialPlatform.instagram:
        return profile.instagramUrl;
      case ProfileSocialPlatform.youtube:
        return profile.youtubeUrl;
      case ProfileSocialPlatform.spotify:
        return profile.spotifyEmbedUrl;
    }
  }

  String? _memberHeadline(List<BandMemberSummary> members) {
    if (members.isEmpty) return null;
    if (members.length == 1) return members.first.username;
    return '${members.first.username} +${members.length - 1}';
  }
}
