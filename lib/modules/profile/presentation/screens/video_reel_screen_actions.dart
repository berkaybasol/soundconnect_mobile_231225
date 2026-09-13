part of 'video_reel_screen.dart';

extension _VideoReelScreenStateActions on _VideoReelScreenState {
  void _stopPlayback({bool dispose = false}) {
    final controller = _playerController;
    if (controller == null) return;
    if (controller.videoPlayerController != null) {
      // Pause/mute return Futures: a synchronous try/catch cannot handle a
      // native teardown error. These are best-effort stop operations; decode
      // failures continue to surface through _playbackEvent's retry UI.
      unawaited(controller.pause().catchError((Object _) {}));
      unawaited(controller.setVolume(0).catchError((Object _) {}));
    }
    if (dispose) {
      _playerController = null;
      controller.removeEventsListener(_playbackEvent);
      controller.dispose();
    }
  }

  Future<void> _retryPlayer() async {
    if (!mounted || _retrying || widget.isPlaybackAllowed?.call() == false) {
      return;
    }
    final position = _playerController?.videoPlayerController?.value.position;
    _updateState(() => _retrying = true);
    try {
      final refresh = widget.refreshPlaybackUrl;
      final url = refresh == null ? null : await refresh();
      if (!mounted || widget.isPlaybackAllowed?.call() == false) return;
      if (refresh != null && resolveAppMediaUrl(url) == null) {
        _updateState(
          () => _playerError = 'Video erişimi yenilenemedi. Yeniden dene.',
        );
        return;
      }
      _stopPlayback(dispose: true);
      await _initPlayer(overrideUrl: url, startAt: position);
    } catch (_) {
      _updateState(
        () => _playerError = 'Video erişimi yenilenemedi. Yeniden dene.',
      );
    } finally {
      _updateState(() => _retrying = false);
    }
  }

  Future<void> _initPlayer({String? overrideUrl, Duration? startAt}) async {
    if (widget.isPlaybackAllowed?.call() == false) {
      _checkAccess();
      return;
    }
    final primary = resolveAppMediaUrl(overrideUrl ?? widget.sourceUrl);
    final secondary = overrideUrl == null
        ? resolveAppMediaUrl(widget.playbackUrl)
        : null;
    final candidates = <String>[
      if (primary != null) primary,
      if (secondary != null && secondary != primary) secondary,
    ];
    if (candidates.isEmpty) {
      _updateState(() => _playerError = 'Video kaynağı açılamadı.');
      return;
    }

    BetterPlayerController buildController(
      String url, {
      required BetterPlayerVideoFormat format,
      required bool useAsms,
    }) {
      final source = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        videoFormat: format,
        useAsmsTracks: useAsms,
        useAsmsSubtitles: useAsms,
        useAsmsAudioTracks: useAsms,
        placeholder: ColoredBox(color: AppColors.pureBlack),
      );
      return BetterPlayerController(
        BetterPlayerConfiguration(
          startAt: startAt,
          eventListener: _playbackEvent,
          autoDispose: true,
          autoPlay: true,
          looping: widget.looping,
          fit: BoxFit.cover,
          expandToFill: false,
          handleLifecycle: true,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enablePlayPause: true,
            enableSkips: true,
            enableProgressBar: true,
            enableProgressText: true,
            enableFullscreen: true,
            enableOverflowMenu: true,
            enableAudioTracks: true,
            enableQualities: true,
            enableSubtitles: true,
            controlBarColor: Color(0x55000000),
            iconsColor: AppColors.white,
            progressBarPlayedColor: AppColors.coralAlt,
            progressBarHandleColor: AppColors.white,
            progressBarBufferedColor: Color(0x88FFFFFF),
            progressBarBackgroundColor: Color(0x55FFFFFF),
          ),
        ),
        betterPlayerDataSource:
            widget.dataSourceFactory?.call(source) ?? source,
      );
    }

    for (final url in candidates) {
      final isHls = url.toLowerCase().contains('.m3u8');
      try {
        final controller = buildController(
          url,
          format: isHls
              ? BetterPlayerVideoFormat.hls
              : BetterPlayerVideoFormat.other,
          useAsms: isHls,
        );
        if (!mounted || widget.isPlaybackAllowed?.call() == false) {
          controller.dispose();
          return;
        }
        _updateState(() {
          _playerController = controller;
          _playerError = null;
        });
        return;
      } catch (_) {
        try {
          final alt = buildController(
            url,
            format: BetterPlayerVideoFormat.other,
            useAsms: false,
          );
          if (!mounted || widget.isPlaybackAllowed?.call() == false) {
            alt.dispose();
            return;
          }
          _updateState(() {
            _playerController = alt;
            _playerError = null;
          });
          return;
        } catch (_) {}
      }
    }

    if (!mounted) return;
    _updateState(() {
      _playerController = null;
      _playerError = 'Video oynatilamadi.';
    });
  }

  Future<void> _openCommentsSheet() async {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final cubit = context.read<CommentThreadCubit>();
    final stats = context.read<InteractionStatsCubit>();
    _stopPlayback();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CommentThreadSheet(
          targetType: widget.targetType,
          targetId: widget.targetId,
          onCommentCreated: () => stats.load(
            targetType: widget.targetType,
            targetId: widget.targetId,
            force: true,
          ),
          onCommentDeleted: () => stats.load(
            targetType: widget.targetType,
            targetId: widget.targetId,
            force: true,
          ),
        ),
      ),
    );
  }
}
