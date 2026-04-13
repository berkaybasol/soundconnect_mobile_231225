part of 'band_profile_screen.dart';

extension _BandProfileViewStateActions on _BandProfileViewState {
  Future<void> _loadBandProfile() async {
    final bandId = _bandId;
    if (bandId == null || bandId.isEmpty) return;

    _updateState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await () async {
      if (_viewMode == BandProfileViewMode.public) {
        return _bandRepository.getPublicBandById(bandId);
      }
      final ownerResult = await _bandRepository.getBandById(bandId);
      if (ownerResult.isSuccess && ownerResult.data != null) {
        return ownerResult;
      }
      return _bandRepository.getPublicBandById(bandId);
    }();

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
      _activeVenues = const [];
    });
    unawaited(_hydrateMemberMetadata(result.data!.members));

    await _loadActiveVenues(result.data!.id);
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
    if (!_canManageBand) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu islem icin yetkiniz yok.')),
        );
      }
      return false;
    }
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
    if (!_canManageBand) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu islem icin yetkiniz yok.')),
      );
      return;
    }
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
    if (!_canManageBand) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu islem icin yetkiniz yok.')),
      );
      return;
    }
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
    if (!_canManageBand) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu islem icin yetkiniz yok.')),
      );
      return;
    }
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
    if (!_canManageBand) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yonetim paneline erisim yok.')),
      );
      return;
    }
    final profile = _profile;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BandManagementPanelScreen(profile: profile),
      ),
    );

    if (!mounted) return;
    await _loadActiveVenues(profile.id);
  }

  Future<void> _loadActiveVenues(String bandId) async {
    final result = await _artistVenueRepository.getVenueConnectionsByBandStatus(
      bandId,
      status: 'ACCEPTED',
    );
    if (!mounted) return;

    final List<VenueConnection> connections =
        result.isSuccess && result.data != null
        ? result.data!
              .where(
                (item) =>
                    item.venueId.trim().isNotEmpty &&
                    item.venueName.trim().isNotEmpty,
              )
              .toList()
        : const [];

    _updateState(() {
      _activeVenues = connections;
    });
  }

  String? _effectiveMemberAvatar(BandMemberSummary member) {
    final String direct = member.profilePictureUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final String cached =
        _resolvedMemberAvatarUrlsByUserId[member.userId]?.trim() ?? '';
    return cached.isEmpty ? null : cached;
  }

  Future<void> _openMemberProfile(BandMemberSummary member) async {
    final String profileId = await _resolveMemberProfileId(member) ?? '';
    if (!mounted) return;
    if (profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu üye için profil bilgisi bulunamadı.')),
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.musicianPublicProfile,
      arguments: PublicProfileArgs(profileId: profileId),
    );
  }

  Future<String?> _resolveMemberProfileId(BandMemberSummary member) async {
    final String direct = member.profileId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final String cached =
        _resolvedMemberProfileIdsByUserId[member.userId]?.trim() ?? '';
    if (cached.isNotEmpty) return cached;

    await _resolveSingleMemberMetadata(member);
    final String resolved =
        _resolvedMemberProfileIdsByUserId[member.userId]?.trim() ?? '';
    return resolved.isEmpty ? null : resolved;
  }

  Future<void> _hydrateMemberMetadata(List<BandMemberSummary> members) async {
    if (members.isEmpty) return;
    for (final member in members) {
      await _resolveSingleMemberMetadata(member);
    }
  }

  Future<void> _resolveSingleMemberMetadata(BandMemberSummary member) async {
    final String userId = member.userId.trim();
    if (userId.isEmpty || _resolvingMemberUserIds.contains(userId)) return;

    final bool hasProfileId =
        (member.profileId?.trim().isNotEmpty ?? false) ||
        (_resolvedMemberProfileIdsByUserId[userId]?.trim().isNotEmpty ?? false);
    final bool hasAvatar =
        (member.profilePictureUrl?.trim().isNotEmpty ?? false) ||
        (_resolvedMemberAvatarUrlsByUserId[userId]?.trim().isNotEmpty ?? false);
    if (hasProfileId && hasAvatar) return;

    _resolvingMemberUserIds.add(userId);
    try {
      String? resolvedProfileId = member.profileId?.trim();
      String? resolvedAvatar = member.profilePictureUrl?.trim();
      if (resolvedAvatar != null && resolvedAvatar.isEmpty) {
        resolvedAvatar = null;
      }

      Future<void> bindByProfileId(String? candidate) async {
        final String id = candidate?.trim() ?? '';
        if (id.isEmpty) return;
        final result = await _musicianProfileRepository
            .getPublicProfileByProfileId(id);
        if (!result.isSuccess || result.data == null) return;
        final profile = result.data!;
        if (profile.id.trim().isNotEmpty) {
          resolvedProfileId = profile.id.trim();
        }
        final String photo = (profile.profilePicture ?? '').trim();
        if (photo.isNotEmpty) {
          resolvedAvatar = photo;
        }
      }

      await bindByProfileId(resolvedProfileId);
      if ((resolvedProfileId ?? '').isEmpty) {
        await bindByProfileId(member.userId);
      }

      if ((resolvedProfileId ?? '').isEmpty) {
        final String query = member.username.trim();
        if (query.isNotEmpty) {
          final search = await _musicianSearchRepository.search(query);
          if (search.isSuccess &&
              search.data != null &&
              search.data!.isNotEmpty) {
            final String usernameLower = query.toLowerCase();
            final exact = search.data!.firstWhere(
              (item) =>
                  item.displayName.trim().toLowerCase() == usernameLower ||
                  (item.secondaryLabel?.trim().toLowerCase() ?? '') ==
                      '@$usernameLower',
              orElse: () => search.data!.first,
            );
            resolvedProfileId = exact.profileId.trim();
            final String searchAvatar = (exact.profilePictureUrl ?? '').trim();
            if (searchAvatar.isNotEmpty) {
              resolvedAvatar = searchAvatar;
            }
            await bindByProfileId(resolvedProfileId);
          }
        }
      }

      final bool changed = _upsertResolvedMember(
        userId: userId,
        profileId: resolvedProfileId,
        avatarUrl: resolvedAvatar,
      );
      if (changed && mounted) {
        _updateState(() {});
      }
    } finally {
      _resolvingMemberUserIds.remove(userId);
    }
  }

  bool _upsertResolvedMember({
    required String userId,
    required String? profileId,
    required String? avatarUrl,
  }) {
    var changed = false;
    final String profileValue = profileId?.trim() ?? '';
    final String avatarValue = avatarUrl?.trim() ?? '';

    if (profileValue.isNotEmpty &&
        _resolvedMemberProfileIdsByUserId[userId] != profileValue) {
      _resolvedMemberProfileIdsByUserId[userId] = profileValue;
      changed = true;
    }
    if (avatarValue.isNotEmpty &&
        _resolvedMemberAvatarUrlsByUserId[userId] != avatarValue) {
      _resolvedMemberAvatarUrlsByUserId[userId] = avatarValue;
      changed = true;
    }

    return changed;
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
