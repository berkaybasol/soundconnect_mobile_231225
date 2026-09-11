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
  }

  Future<void> _loadShareUrl() async {
    try {
      final result = await _venueEventRepository.getDetail(widget.event.id);
      final payload = result.data;
      if (!mounted ||
          !result.isSuccess ||
          payload == null ||
          payload.id != widget.event.id) {
        return;
      }
      _updateState(() {
        // Summaries may omit description; only the event detail is authoritative.
        _loadedDescription = payload.description?.trim() ?? '';
        _analyticsEventVerified =
            payload.venueId == widget.event.venueId &&
            (widget.event.venueId?.trim().isNotEmpty ?? false);
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
    try {
      final repository = serviceLocator<BandRepository>();
      final result = await repository.getPublicBandById(bandId);
      if (!mounted ||
          !result.isSuccess ||
          result.data == null ||
          result.data!.id.trim() != bandId ||
          widget.event.linkedBandProfileId != bandId) {
        return;
      }
      _updateState(() => _bandProfile = result.data);
    } catch (_) {
      // A missing preview must not break the event. Retry its identity lookup
      // when the chip is tapped, rather than guessing band ownership.
    }
  }

  Future<void> _loadVenueProfile(String venueId) async {
    try {
      final repository = serviceLocator<VenueProfileRepository>();
      final result = await repository.getPublicVenueProfile(venueId: venueId);
      if (!mounted ||
          !result.isSuccess ||
          result.data == null ||
          result.data!.venueId != venueId ||
          widget.event.venueId != venueId) {
        return;
      }
      _updateState(() => _venueProfile = result.data);
    } catch (_) {
      // A failed public preview cannot grant access to private analytics.
    }
  }

  Future<void> _loadComments({bool clearExisting = false}) async {
    await _commentCubit.load(
      targetType: 'EVENT',
      targetId: widget.event.id,
      clearExisting: clearExisting,
    );
  }

  Future<void> _loadReplies(String commentId, {bool restart = false}) async {
    if (!mounted ||
        !_expandedReplyParents.contains(commentId) ||
        (!restart &&
            (_loadingReplyParents.contains(commentId) ||
                (_loadedReplyParents.contains(commentId) &&
                    _replyHasMore[commentId] != true)))) {
      return;
    }
    final roots = _commentCubit.state.comments.where(
      (item) => item.id == commentId,
    );
    if (roots.isEmpty) {
      return;
    }
    final root = roots.first;
    final identityRevision = _commentIdentityRevision;
    final expectedSession = _commentSessionManager?.session;
    final eventId = widget.event.id;
    final page = restart ? 0 : (_replyPages[commentId] ?? 0);
    if (page > 1000) return;
    final requestVersion = (_replyRequestVersions[commentId] ?? 0) + 1;
    _replyRequestVersions[commentId] = requestVersion;
    _replyRootSnapshots[commentId] = root;
    bool currentRequest() =>
        mounted &&
        identityRevision == _commentIdentityRevision &&
        identical(expectedSession, _commentSessionManager?.session) &&
        eventId == widget.event.id &&
        _replyRequestVersions[commentId] == requestVersion &&
        _commentCubit.state.comments.any((item) => identical(item, root));
    _updateState(() {
      _loadingReplyParents.add(commentId);
      _replyErrors.remove(commentId);
    });
    try {
      final result = await _engagementRepository.listReplyPage(
        commentId,
        eventId: eventId,
        page: page,
        size: 20,
      );
      if (!currentRequest()) {
        return;
      }
      final data = result.data;
      _updateState(() {
        _loadingReplyParents.remove(commentId);
        if (!result.isSuccess || data == null) {
          _replyErrors.add(commentId);
          return;
        }
        final rows = <String, CommentItem>{
          if (!restart)
            for (final item
                in _repliesByCommentId[commentId] ?? <CommentItem>[])
              item.id: item,
          for (final item in data.items) item.id: item,
        };
        _repliesByCommentId[commentId] = rows.values.toList(growable: false);
        _loadedReplyParents.add(commentId);
        _replyPages[commentId] = page + 1;
        _replyTotals[commentId] = data.totalElements;
        _replyHasMore[commentId] =
            data.items.isNotEmpty &&
            page < 1000 &&
            (page + 1) * 20 < data.totalElements;
      });
    } catch (_) {
      if (!currentRequest()) {
        return;
      }
      _updateState(() {
        _loadingReplyParents.remove(commentId);
        _replyErrors.add(commentId);
      });
    }
  }

  String _timeLabel(DateTime? createdAt) => formatCommentAge(createdAt);

  Future<void> _addComment(
    AuthSession? expectedSession,
    String expectedEventId,
  ) async {
    if (!_isCurrentCommentSession(expectedSession) ||
        widget.event.id != expectedEventId ||
        ModalRoute.of(context)?.isCurrent != true ||
        _commentCubit.state.submitting) {
      return;
    }
    final originalText = _commentController.text;
    final text = originalText.trim();
    if (!CommentText.isValid(text)) return;
    final sent = await _commentCubit.create(
      targetType: 'EVENT',
      targetId: expectedEventId,
      text: text,
    );
    if (_isCurrentCommentSession(expectedSession) &&
        widget.event.id == expectedEventId &&
        sent &&
        _commentController.text == originalText) {
      _commentController.clear();
    }
    if (_isCurrentCommentSession(expectedSession) &&
        widget.event.id == expectedEventId &&
        sent) {
      widget.onEngagementChanged?.call();
    }
    if (!sent &&
        mounted &&
        _isCurrentCommentSession(expectedSession) &&
        ModalRoute.of(context)?.isCurrent == true &&
        _commentCubit.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(_commentCubit.state.error!.message),
        ),
      );
    }
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
      final viewerId = session?.userId?.trim() ?? '';
      final canResolveOwnership =
          session?.isAuthenticated == true &&
          session?.isActive == true &&
          viewerId.isNotEmpty &&
          session!.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']);
      if (bandId != null && bandId.isNotEmpty) {
        var opensOwnBand = false;
        if (canResolveOwnership) {
          var profile = _bandProfile;
          if (profile == null || profile.id.trim() != bandId) {
            final result = await serviceLocator<BandRepository>()
                .getPublicBandById(bandId);
            if (!canNavigate()) return;
            profile = result.data;
            if (!result.isSuccess ||
                profile == null ||
                profile.id.trim() != bandId) {
              throw StateError('Band ownership could not be verified');
            }
          }
          // Names and general membership do not confer ownership. The band
          // screen re-fetches the profile and rechecks founder access in auto.
          opensOwnBand = profile.members.any(
            (member) =>
                member.userId.trim() == viewerId &&
                member.isFounder &&
                member.status.trim().toUpperCase() == 'ACTIVE',
          );
        }
        if (!mounted || !canNavigate()) return;
        await Navigator.of(context).pushNamed(
          opensOwnBand ? AppRoutes.bandProfile : AppRoutes.bandPublicProfile,
          arguments: BandProfileScreenArgs(
            bandId: bandId,
            viewMode: opensOwnBand
                ? BandProfileViewMode.auto
                : BandProfileViewMode.public,
          ),
        );
        return;
      }
      if (profileId == null || profileId.isEmpty) return;
      var opensOwnProfile = false;
      if (canResolveOwnership) {
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Profil açılamadı. Lütfen tekrar dene.'),
        ),
      );
    } finally {
      _isOpeningArtistProfile = false;
    }
  }

  void _openVenueProfile() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final venueId = widget.event.venueId?.trim();
    if (venueId == null || venueId.isEmpty) return;
    // A tap on the verified, current detail is also an actual page visit. Queue
    // it before navigation so a very quick profile tap retains attribution.
    if (_analyticsEventVerified &&
        serviceLocator.isRegistered<AnalyticsTracker>()) {
      serviceLocator<AnalyticsTracker>().recordEventDetailView(widget.event.id);
    }
    Navigator.of(context).pushNamed(
      AppRoutes.venuePublicProfile,
      arguments: VenuePublicProfileArgs(
        venueId: venueId,
        sourceEventId: _analyticsEventVerified ? widget.event.id : null,
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
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Paylaşım hazırlanamadı. Lütfen tekrar dene.'),
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

  Future<void> _showReplySheet(
    CommentItem targetComment,
    AuthSession? expectedSession,
  ) async {
    if (!_isCurrentCommentSession(expectedSession) ||
        ModalRoute.of(context)?.isCurrent != true ||
        _showingReply ||
        _commentCubit.state.submitting) {
      return;
    }
    if (!_commentCubit.state.comments.any(
      (item) => item.id == targetComment.id,
    )) {
      return;
    }
    _showingReply = true;
    final eventId = widget.event.id;
    ModalRoute<dynamic>? ownedRoute;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.navBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) {
          ownedRoute = ModalRoute.of(sheetContext);
          _replyRoute = ownedRoute;
          if (!_isCurrentCommentSession(expectedSession) ||
              widget.event.id != eventId) {
            _dismissReplyRoute();
          }
          return _EventReplyComposer(
            canSubmit: () =>
                _isCurrentCommentSession(expectedSession) &&
                widget.event.id == eventId,
            onSubmit: (text) async {
              if (!_isCurrentCommentSession(expectedSession) ||
                  widget.event.id != eventId ||
                  ownedRoute?.isCurrent != true) {
                return false;
              }
              final wasExpanded = _expandedReplyParents.contains(
                targetComment.id,
              );
              final sent = await _commentCubit.create(
                targetType: 'EVENT',
                targetId: eventId,
                text: text,
                parentCommentId: targetComment.id,
              );
              if (sent &&
                  _isCurrentCommentSession(expectedSession) &&
                  widget.event.id == eventId &&
                  wasExpanded &&
                  _commentCubit.state.comments.any(
                    (item) => item.id == targetComment.id,
                  )) {
                _updateState(() => _expandedReplyParents.add(targetComment.id));
                await _loadReplies(targetComment.id, restart: true);
              }
              if (sent &&
                  _isCurrentCommentSession(expectedSession) &&
                  widget.event.id == eventId) {
                widget.onEngagementChanged?.call();
              }
              return sent;
            },
            errorText: () => _commentCubit.state.error?.message,
          );
        },
      );
      await ownedRoute?.completed;
    } finally {
      _showingReply = false;
      if (identical(_replyRoute, ownedRoute)) _replyRoute = null;
    }
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
