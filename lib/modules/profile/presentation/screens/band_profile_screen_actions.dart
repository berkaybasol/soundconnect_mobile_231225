part of 'band_profile_screen.dart';

extension _BandProfileViewStateActions on _BandProfileViewState {
  Future<void> _loadBandProfile({bool showLoading = true}) async {
    if (_leavingBand) return;
    final bandId = _bandId;
    if (bandId == null || bandId.isEmpty) return;
    final generation = ++_profileLoadGeneration;
    bool isCurrent() =>
        mounted && generation == _profileLoadGeneration && bandId == _bandId;

    _updateState(() {
      if (showLoading) _loading = true;
      _errorText = null;
    });

    try {
      final result = await () async {
        if (_viewMode == BandProfileViewMode.public) {
          return _bandRepository.getPublicBandById(bandId);
        }
        try {
          final ownerResult = await _bandRepository.getBandById(bandId);
          if (!isCurrent()) return null;
          if (ownerResult.isSuccess && ownerResult.data != null) {
            return ownerResult;
          }
        } catch (_) {
          if (!isCurrent()) return null;
        }
        return _bandRepository.getPublicBandById(bandId);
      }();
      if (!isCurrent()) return;

      final profile = result?.data;
      if (result == null ||
          !result.isSuccess ||
          profile == null ||
          profile.id.trim() != bandId.trim()) {
        _updateState(() {
          _loading = false;
          _profile = null;
          _errorText = result?.error?.message ?? 'Band profili getirilemedi.';
        });
        return;
      }

      _updateState(() {
        _loading = false;
        _profile = profile;
        _activeVenues = const [];
      });
      unawaited(_hydrateMemberMetadata(profile.members));

      Future<void> loadOptional(Future<void> Function() loader) async {
        if (!isCurrent()) return;
        try {
          await loader();
        } catch (_) {
          // Secondary profile sections must not hide a valid membership or
          // prevent its actions when an unrelated service is unavailable.
        }
      }

      await loadOptional(() => _loadActiveVenues(profile.id));
      await loadOptional(() => _loadFollowersCount(profile.id));
      await loadOptional(() => _loadBandFollowStatus(profile.id));
      await loadOptional(() => _loadSpotifyCatalog(profile));
      await loadOptional(
        () => context.read<ProfileMediaCubit>().loadMedia(
          profileType: 'BAND',
          profileId: profile.id,
        ),
      );
    } catch (_) {
      if (!isCurrent()) return;
      _updateState(() {
        _loading = false;
        _profile = null;
        _errorText = 'Band profili getirilemedi. Lütfen tekrar dene.';
      });
    }
  }

  Future<void> _loadSpotifyCatalog(BandProfile profile) async {
    final generation = _profileLoadGeneration;
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
    try {
      final result = await _spotifyRepository.getTracksByIds(trackIds);
      if (!mounted || generation != _profileLoadGeneration) return;
      _updateState(() {
        _spotifyTracks = result.isSuccess && result.data != null
            ? result.data!
            : const [];
      });
    } finally {
      if (mounted && generation == _profileLoadGeneration) {
        _updateState(() => _spotifyLoading = false);
      }
    }
  }

  Future<void> _loadFollowersCount(String bandId) async {
    final generation = _profileLoadGeneration;
    final result = await _bandFollowRepository.getFollowersCount(bandId);
    if (!mounted || generation != _profileLoadGeneration) return;
    _updateState(() {
      _followersCount = result.data;
    });
  }

  Future<void> _loadBandFollowStatus(String bandId) async {
    final generation = _profileLoadGeneration;
    if ((_currentUserId ?? '').trim().isEmpty) return;
    final profile = _profile;
    if (profile != null &&
        (_canManageBand || _isCurrentUserActiveBandMember(profile))) {
      return;
    }

    final result = await _bandFollowRepository.isFollowingBand(bandId);
    if (!mounted || generation != _profileLoadGeneration) return;
    if (result.isSuccess && result.data != null) {
      _updateState(() {
        _isFollowingBand = result.data!;
      });
    }
  }

  Future<void> _toggleBandFollow(String bandId) async {
    if (_bandFollowLoading) return;
    if ((_currentUserId ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text('Takip etmek için giriş yapmalısın.'),
        ),
      );
      return;
    }

    _updateState(() => _bandFollowLoading = true);
    final wasFollowing = _isFollowingBand;
    final result = wasFollowing
        ? await _bandFollowRepository.unfollowBand(bandId)
        : await _bandFollowRepository.followBand(bandId);

    if (!mounted) return;

    if (!result.isSuccess) {
      _updateState(() => _bandFollowLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(
            result.error?.message ??
                (wasFollowing
                    ? 'Band takipten çıkarılamadı.'
                    : 'Band takip edilemedi.'),
          ),
        ),
      );
      return;
    }

    _updateState(() {
      _bandFollowLoading = false;
      _isFollowingBand = !wasFollowing;
      final count = _followersCount;
      if (count != null) {
        _followersCount = wasFollowing
            ? (count > 0 ? count - 1 : 0)
            : count + 1;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.success,
        content: Text(
          wasFollowing ? 'Band takipten çıkarıldı.' : 'Band takip edildi.',
        ),
      ),
    );
  }

  Future<bool> _saveSpotifyTracks(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  }) async {
    if (!_canManageBand) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.warning,
            content: const Text('Bu işlem için yetkin yok.'),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(message),
        ),
      );
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text('Bu işlem için yetkin yok.'),
        ),
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(result.error?.message ?? 'Açıklama kaydedilemedi.'),
        ),
      );
      return;
    }

    _updateState(() {
      _profile = result.data;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.success,
        content: const Text('Açıklama güncellendi.'),
      ),
    );
  }

  Future<void> _editProfilePhoto() async {
    if (!_canManageBand) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text('Bu işlem için yetkin yok.'),
        ),
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
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: Text(
              result.error?.message ?? 'Profil fotoğrafı güncellenemedi.',
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Profil fotoğrafı güncellendi.'),
        ),
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text('Bu işlem için yetkin yok.'),
        ),
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(result.error?.message ?? 'Sosyal link kaydedilemedi.'),
        ),
      );
      return;
    }

    _updateState(() {
      _profile = result.data;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.success,
        content: Text('${platform.label} güncellendi.'),
      ),
    );
  }

  Future<void> _openBandManagementPanel(BuildContext context) async {
    if (!_canManageBand) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text('Yönetim paneline erişim yok.'),
        ),
      );
      return;
    }
    final profile = _profile;
    if (profile == null) return;

    final session = _membershipSessionManager?.session;
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BandManagementPanelScreen(profile: profile),
      ),
    );

    if (!context.mounted ||
        !identical(_membershipSessionManager?.session, session) ||
        _bandId != profile.id ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (deleted == true) {
      Navigator.of(context).pop(true);
      return;
    }
    await _loadBandProfile(showLoading: false);
  }

  Future<void> _loadActiveVenues(String bandId) async {
    final generation = _profileLoadGeneration;
    final result = await _artistVenueRepository.getVenueConnectionsByBandStatus(
      bandId,
      status: 'ACCEPTED',
    );
    if (!mounted || generation != _profileLoadGeneration) return;

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
    final bandId = _profile?.id;
    await _memberProfileResolver.open(
      context,
      member,
      isMemberCurrent: () =>
          _profile?.id == bandId &&
          (_profile?.members.any(
                (current) =>
                    current.userId == member.userId &&
                    current.profileId == member.profileId,
              ) ??
              false),
    );
  }

  Future<void> _hydrateMemberMetadata(List<BandMemberSummary> members) async {
    for (final member in members) {
      if (!mounted) return;
      await _resolveSingleMemberMetadata(member);
    }
  }

  Future<void> _resolveSingleMemberMetadata(BandMemberSummary member) async {
    final userId = member.userId.trim();
    if (userId.isEmpty || _resolvingMemberUserIds.contains(userId)) return;
    final hasProfileId =
        (member.profileId?.trim().isNotEmpty ?? false) ||
        (_resolvedMemberProfileIdsByUserId[userId]?.trim().isNotEmpty ?? false);
    final hasAvatar =
        (member.profilePictureUrl?.trim().isNotEmpty ?? false) ||
        (_resolvedMemberAvatarUrlsByUserId[userId]?.trim().isNotEmpty ?? false);
    if (hasProfileId && hasAvatar) return;

    _resolvingMemberUserIds.add(userId);
    try {
      final profile = await _memberProfileResolver.resolve(member);
      if (!mounted || profile == null) return;
      if (!(_profile?.members.any(
            (current) =>
                current.userId == member.userId &&
                current.profileId == member.profileId,
          ) ??
          false)) {
        return;
      }
      final changed = _upsertResolvedMember(
        userId: userId,
        profileId: profile.id,
        avatarUrl: profile.profilePicture,
      );
      if (changed) _updateState(() {});
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
