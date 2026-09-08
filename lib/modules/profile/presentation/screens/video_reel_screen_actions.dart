part of 'video_reel_screen.dart';

extension _VideoReelScreenStateActions on _VideoReelScreenState {
  void _stopPlayback({bool dispose = false}) {
    final controller = _playerController;
    if (controller == null) return;
    try {
      controller.pause();
      controller.setVolume(0);
    } catch (_) {}
    if (dispose) {
      controller.dispose();
      _playerController = null;
    }
  }

  Future<void> _initPlayer() async {
    final primary = (widget.sourceUrl ?? '').trim();
    final secondary = widget.playbackUrl.trim();
    final candidates = <String>[
      if (primary.isNotEmpty) primary,
      if (secondary.isNotEmpty && secondary != primary) secondary,
    ];
    if (candidates.isEmpty) return;

    BetterPlayerController buildController(
      String url, {
      required BetterPlayerVideoFormat format,
      required bool useAsms,
    }) {
      return BetterPlayerController(
        BetterPlayerConfiguration(
          autoDispose: true,
          autoPlay: true,
          looping: true,
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
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          url,
          videoFormat: format,
          useAsmsTracks: useAsms,
          useAsmsSubtitles: useAsms,
          useAsmsAudioTracks: useAsms,
          placeholder: ColoredBox(color: AppColors.pureBlack),
        ),
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
        if (!mounted) {
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
          if (!mounted) {
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
