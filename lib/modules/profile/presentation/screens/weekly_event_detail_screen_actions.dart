// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously, invalid_use_of_protected_member

part of 'weekly_event_detail_screen.dart';

extension _WeeklyEventDetailScreenStateActions
    on _WeeklyEventDetailScreenState {
  Future<void> _loadProfileContext() async {
    final futures = <Future<void>>[];
    final artistProfileId = widget.event.artistProfileId?.trim();
    final venueId = widget.event.venueId?.trim();

    futures.add(_loadShareUrl());

    if (artistProfileId != null && artistProfileId.isNotEmpty) {
      futures.add(_loadArtistProfile(artistProfileId));
    }
    if (venueId != null && venueId.isNotEmpty) {
      futures.add(_loadVenueProfile(venueId));
    }

    if (futures.isEmpty) return;
    await Future.wait(futures);
    await _loadComments();
  }

  Future<void> _loadShareUrl() async {
    try {
      final result = await _venueEventRepository.getDetail(widget.event.id);
      final payload = result.data;
      if (!mounted) return;
      final shareUrl = payload?.shareUrl?.trim() ?? '';
      if (shareUrl.isEmpty) return;
      setState(() {
        _shareUrl = shareUrl;
      });
    } catch (_) {
      // Share butonu fallback metinle yine calisabilir.
    }
  }

  Future<void> _loadArtistProfile(String profileId) async {
    final repository = serviceLocator<MusicianProfileRepository>();
    final result = await repository.getPublicProfileByProfileId(profileId);
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
      _artistProfile = result.data;
    });
  }

  Future<void> _loadVenueProfile(String venueId) async {
    final repository = serviceLocator<VenueProfileRepository>();
    final result = await repository.getPublicVenueProfile(venueId: venueId);
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
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
      final items = result.data ?? const <CommentItem>[];
      if (!mounted) return;
      setState(() {
        _repliesByCommentId[commentId] = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _repliesByCommentId[commentId] = const <CommentItem>[];
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

  void _openArtistProfile() {
    final profileId = widget.event.artistProfileId?.trim();
    if (profileId == null || profileId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: PublicProfileArgs(profileId: profileId),
        ),
        builder: (_) => const musician_public.MusicianPublicProfileScreen(),
      ),
    );
  }

  void _openVenueProfile() {
    final venueId = widget.event.venueId?.trim();
    if (venueId == null || venueId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: VenuePublicProfileArgs(venueId: venueId),
        ),
        builder: (_) => const venue_public.VenuePublicProfileScreen(),
      ),
    );
  }

  Future<void> _shareEvent() async {
    if (_isSharing) return;
    final shareUrl = _shareUrl?.trim();
    final shareText = shareUrl != null && shareUrl.isNotEmpty
        ? '${widget.event.title}\n$shareUrl'
        : '${widget.event.title}\n'
              '${widget.event.eventDate} ${widget.event.startTime} - ${widget.event.endTime}\n'
              '@${widget.event.venueName}';
    setState(() {
      _isSharing = true;
    });
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: widget.event.title,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paylasim acilamadi.')));
    } finally {
      if (mounted) {
        setState(() {
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
      shape: const RoundedRectangleBorder(
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
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Yanita yaz...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Ekle'),
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
    final imagePath = widget.event.imageAssetPath;
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Poster',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (context, _, __) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: imagePath != null
                        ? _isNetworkLikePath(imagePath)
                              ? Image.network(
                                  imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _imageFallback(),
                                )
                              : Image.asset(
                                  imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _imageFallback(),
                                )
                        : _imageFallback(),
                  ),
                ),
              ),
              Positioned(
                top: 44,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
