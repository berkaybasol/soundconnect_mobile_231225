// ignore_for_file: use_build_context_synchronously, unused_element, unused_element_parameter, unused_local_variable, invalid_use_of_protected_member

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
          controlsConfiguration: const BetterPlayerControlsConfiguration(
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
            iconsColor: Colors.white,
            progressBarPlayedColor: AppColors.coralAlt,
            progressBarHandleColor: Colors.white,
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
          placeholder: const ColoredBox(color: Colors.black),
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
        setState(() {
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
          setState(() {
            _playerController = alt;
            _playerError = null;
          });
          return;
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
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
      shape: const RoundedRectangleBorder(
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
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Yorumlar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: BlocBuilder<CommentThreadCubit, CommentThreadState>(
                      builder: (context, state) {
                        if (state.loading && state.comments.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (state.comments.isEmpty) {
                          return const Center(
                            child: Text(
                              'Henuz yorum yok.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          itemCount: state.comments.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: AppColors.border,
                            height: 14,
                          ),
                          itemBuilder: (context, i) {
                            final c = state.comments[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.navBlueSoft,
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.textMuted,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@${c.user.username}',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        c.text,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: inputController,
                            decoration: InputDecoration(
                              hintText: 'Yorum yaz...',
                              hintStyle: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                              filled: true,
                              fillColor: AppColors.inputFill,
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
                            await cubit.create(
                              targetType: widget.targetType,
                              targetId: widget.targetId,
                              text: text,
                            );
                            await context.read<InteractionStatsCubit>().load(
                              targetType: widget.targetType,
                              targetId: widget.targetId,
                              force: true,
                            );
                            inputController.clear();
                          },
                          icon: const Icon(
                            Icons.send,
                            color: AppColors.coralAlt,
                          ),
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
