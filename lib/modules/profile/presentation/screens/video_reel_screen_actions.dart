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
    final cubit = context.read<CommentThreadCubit>();
    await cubit.load(targetType: widget.targetType, targetId: widget.targetId);
    if (!mounted) return;
    final inputController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: cubit,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.72,
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Yorumlar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: BlocBuilder<CommentThreadCubit, CommentThreadState>(
                      builder: (context, state) {
                        if (state.loading && state.comments.isEmpty) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (state.comments.isEmpty) {
                          return Center(
                            child: Text(
                              'Henuz yorum yok.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          itemCount: state.comments.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Theme.of(context).dividerColor,
                            height: 14,
                          ),
                          itemBuilder: (context, i) {
                            final c = state.comments[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  child: Icon(
                                    Icons.person,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    size: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@${c.user.username}',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        c.text,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: inputController,
                            decoration: InputDecoration(
                              hintText: 'Yorum yaz...',
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final text = inputController.text.trim();
                            if (text.isEmpty) return;
                            final statsCubit = context
                                .read<InteractionStatsCubit>();
                            await cubit.create(
                              targetType: widget.targetType,
                              targetId: widget.targetId,
                              text: text,
                            );
                            if (!mounted) return;
                            await statsCubit.load(
                              targetType: widget.targetType,
                              targetId: widget.targetId,
                              force: true,
                            );
                            inputController.clear();
                          },
                          icon: Icon(Icons.send, color: AppColors.coralAlt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    inputController.dispose();
  }
}
