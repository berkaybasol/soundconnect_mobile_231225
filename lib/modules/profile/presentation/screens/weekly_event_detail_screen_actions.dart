part of 'weekly_event_detail_screen.dart';

extension _WeeklyEventDetailScreenStateActions
    on _WeeklyEventDetailScreenState {
  Future<void> _loadProfileContext() async {
    final futures = <Future<void>>[];
    final artistProfileId = widget.event.linkedArtistProfileId;
    final bandProfileId = widget.event.linkedBandProfileId;
    final venueId = widget.event.venueId?.trim();

    futures.add(_loadShareUrl());

    if (bandProfileId != null && bandProfileId.isNotEmpty) {
      futures.add(_loadBandProfile(bandProfileId));
    } else if (artistProfileId != null && artistProfileId.isNotEmpty) {
      futures.add(_loadArtistProfile(artistProfileId));
    }
    if (venueId != null && venueId.isNotEmpty) {
      futures.add(_loadVenueProfile(venueId));
    }

    if (futures.isEmpty) return;
    await Future.wait(futures);
    if (!mounted) return;
    await _loadComments();
  }

  Future<void> _loadShareUrl() async {
    try {
      final result = await _venueEventRepository.getDetail(widget.event.id);
      final payload = result.data;
      if (!mounted || !result.isSuccess || payload == null) return;
      _updateState(() {
        // Summaries may omit description; only the event detail is authoritative.
        _loadedDescription = payload.description?.trim() ?? '';
      });
    } catch (_) {
      // Keep the supplied description if the public detail is unavailable.
    }
  }

  Future<void> _loadArtistProfile(String profileId) async {
    try {
      final repository = serviceLocator<MusicianProfileRepository>();
      final result = await repository.getPublicProfileByProfileId(profileId);
      if (!mounted ||
          !result.isSuccess ||
          result.data == null ||
          result.data!.id.trim() != profileId ||
          widget.event.linkedArtistProfileId != profileId) {
        return;
      }
      _updateState(() => _artistProfile = result.data);
    } catch (_) {
      // An unavailable public preview must not break the event. Ownership can
      // still be verified from the signed-in profile when its chip is tapped.
    }
  }

  Future<void> _loadBandProfile(String bandId) async {
    final repository = serviceLocator<BandRepository>();
    final result = await repository.getPublicBandById(bandId);
    if (!mounted || !result.isSuccess || result.data == null) return;
    _updateState(() {
      _bandProfile = result.data;
    });
  }

  Future<void> _loadVenueProfile(String venueId) async {
    final repository = serviceLocator<VenueProfileRepository>();
    final result = await repository.getPublicVenueProfile(venueId: venueId);
    if (!mounted || !result.isSuccess || result.data == null) return;
    _updateState(() {
      _venueProfile = result.data;
    });
  }

  Future<void> _loadComments() async {
    await _commentCubit.load(targetType: 'EVENT', targetId: widget.event.id);
  }

  Future<void> _syncReplies(List<CommentItem> comments) async {
    final futures = <Future<void>>[];
    for (final comment in comments) {
      if (comment.replyCount <= 0) continue;
      if (_loadedReplyParents.contains(comment.id)) continue;
      _loadedReplyParents.add(comment.id);
      futures.add(_loadReplies(comment.id));
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  Future<void> _loadReplies(String commentId) async {
    try {
      final result = await _engagementRepository.listReplies(commentId);
      final items = result.data ?? <CommentItem>[];
      if (!mounted) return;
      _updateState(() {
        _repliesByCommentId[commentId] = items;
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _repliesByCommentId[commentId] = <CommentItem>[];
      });
    }
  }

  String _timeLabel(DateTime? createdAt) {
    if (createdAt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'simdi';
    if (diff.inHours < 1) return '${diff.inMinutes} dk once';
    if (diff.inDays < 1) return '${diff.inHours} sa once';
    return '${diff.inDays} gun once';
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await _commentCubit.create(
      targetType: 'EVENT',
      targetId: widget.event.id,
      text: text,
    );
    _commentController.clear();
  }

  Future<void> _openArtistProfile() async {
    if (!mounted ||
        _isOpeningArtistProfile ||
        ModalRoute.of(context)?.isCurrent != true ||
        !widget.event.hasLinkedPerformerProfile) {
      return;
    }
    final event = widget.event;
    final bandId = event.linkedBandProfileId;
    final profileId = event.linkedArtistProfileId;
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    final session = manager?.session;
    bool canNavigate() =>
        mounted &&
        identical(manager?.session, session) &&
        widget.event.id == event.id &&
        widget.event.linkedArtistProfileId == profileId &&
        widget.event.linkedBandProfileId == bandId &&
        ModalRoute.of(context)?.isCurrent == true;
    _isOpeningArtistProfile = true;
    try {
      if (bandId != null && bandId.isNotEmpty) {
        await Navigator.of(context).pushNamed(
          AppRoutes.bandPublicProfile,
          arguments: BandProfileScreenArgs(
            bandId: bandId,
            viewMode: BandProfileViewMode.public,
          ),
        );
        return;
      }
      if (profileId == null || profileId.isEmpty) return;
      var opensOwnProfile = false;
      final viewerId = session?.userId?.trim() ?? '';
      if (session?.isAuthenticated == true &&
          session?.isActive == true &&
          viewerId.isNotEmpty &&
          session!.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN'])) {
        final publicProfile = _artistProfile;
        if (publicProfile?.id.trim() == profileId &&
            publicProfile!.userId.trim().isNotEmpty) {
          opensOwnProfile = publicProfile.userId.trim() == viewerId;
        } else {
          // The chip can be tapped before its public preview has loaded. Resolve
          // ownership by stable IDs, never by a handle or the event's name.
          final result = await serviceLocator<MusicianProfileRepository>()
              .getMyProfile();
          if (!canNavigate()) return;
          final ownProfile = result.data;
          if (!result.isSuccess ||
              ownProfile == null ||
              ownProfile.id.trim().isEmpty ||
              ownProfile.userId.trim() != viewerId) {
            throw StateError('Profile ownership could not be verified');
          }
          opensOwnProfile = ownProfile.id.trim() == profileId;
        }
      }
      if (!mounted || !canNavigate()) return;
      await Navigator.of(context).pushNamed(
        opensOwnProfile
            ? AppRoutes.musicianProfile
            : AppRoutes.musicianPublicProfile,
        arguments: opensOwnProfile
            ? null
            : PublicProfileArgs(profileId: profileId),
      );
    } catch (_) {
      if (!mounted || !canNavigate()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil açılamadı. Lütfen tekrar dene.')),
      );
    } finally {
      _isOpeningArtistProfile = false;
    }
  }

  void _openVenueProfile() {
    final venueId = widget.event.venueId?.trim();
    if (venueId == null || venueId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: VenuePublicProfileArgs(venueId: venueId),
        ),
        builder: (_) => venue_public.VenuePublicProfileScreen(),
      ),
    );
  }

  Future<void> _shareEvent() async {
    if (!mounted || _isSharing || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    FocusScope.of(context).unfocus();
    _updateState(() {
      _isSharing = true;
    });
    try {
      // Re-read public data before exporting: a stale screen must not imply a
      // withdrawn performer link or share a deleted event as if still current.
      final result = await _venueEventRepository.getDetail(widget.event.id);
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final detail = result.data;
      if (!result.isSuccess ||
          detail == null ||
          detail.id.trim().isEmpty ||
          detail.id != widget.event.id) {
        throw StateError('Event detail is unavailable');
      }
      final data = EventShareData.fromDetail(
        detail,
        venueAvatarUrl: _venueProfile?.venueId == detail.venueId
            ? _venueProfile?.profilePictureUrl
            : null,
      );
      final prepared = await _eventShareService.prepare(context, data);
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final target = await showEventShareSheet(context, prepared);
      if (target == null ||
          !mounted ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      await _eventShareService.share(context, prepared, target);
    } catch (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF202A3D),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Paylaşım hazırlanamadı. Lütfen tekrar dene.',
            style: TextStyle(color: AppColors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        _updateState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _showReplySheet(int index) async {
    final comments = _commentCubit.state.comments;
    if (index < 0 || index >= comments.length) return;
    final targetComment = comments[index];
    final replyController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            14,
            14,
            MediaQuery.of(sheetContext).viewInsets.bottom + 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => Navigator.of(sheetContext).pop(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Yanita yaz...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text('Ekle'),
              ),
            ],
          ),
        );
      },
    );

    final replyText = replyController.text.trim();
    replyController.dispose();
    if (replyText.isEmpty) return;
    await _commentCubit.create(
      targetType: 'EVENT',
      targetId: widget.event.id,
      text: replyText,
      parentCommentId: targetComment.id,
    );
    _loadedReplyParents.remove(targetComment.id);
    await _syncReplies(_commentCubit.state.comments);
  }

  void _openPosterFullScreen() {
    final imagePath = widget.event.imageAssetPath?.trim();
    Widget fallback() => Padding(
      padding: const EdgeInsets.all(24),
      child: AspectRatio(
        aspectRatio: 0.75,
        child: _imageFallback(widget.event, showDetails: true),
      ),
    );
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Poster',
      barrierDismissible: true,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.9),
      pageBuilder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.pureBlack,
          body: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: _isNetworkLikePath(imagePath)
                        ? AppCachedNetworkImage(
                            imageUrl: imagePath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            cacheProfile: AppImageCacheProfile.original,
                            placeholderBuilder: (_) => fallback(),
                            errorBuilder: (_) => fallback(),
                          )
                        : imagePath?.startsWith('assets/') == true
                        ? Image.asset(
                            imagePath!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => fallback(),
                          )
                        : fallback(),
                  ),
                ),
              ),
              Positioned(
                top: 44,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: AppColors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
