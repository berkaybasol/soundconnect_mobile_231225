// ignore_for_file: use_build_context_synchronously

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'video_frame_preset_store.dart';

class VideoReelScreen extends StatefulWidget {
  final String title;
  final String playbackUrl;
  final String? sourceUrl;
  final String? thumbnailUrl;
  final VideoFramePreset? framePreset;
  final String targetType;
  final String targetId;
  final int initialLikeCount;
  final int initialCommentCount;

  const VideoReelScreen({
    super.key,
    required this.title,
    required this.playbackUrl,
    this.sourceUrl,
    this.framePreset,
    required this.thumbnailUrl,
    required this.targetType,
    required this.targetId,
    required this.initialLikeCount,
    required this.initialCommentCount,
  });

  @override
  State<VideoReelScreen> createState() => _VideoReelScreenState();
}

class _VideoReelScreenState extends State<VideoReelScreen>
    with WidgetsBindingObserver {
  BetterPlayerController? _playerController;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
    context.read<InteractionStatsCubit>().load(
      targetType: widget.targetType,
      targetId: widget.targetId,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPlayback(dispose: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPlayback();
    }
  }

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
      _playerError = 'Video oynatılamadı.';
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
        return Padding(
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
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.comments.isEmpty) {
                        return const Center(
                          child: Text(
                            'Hen\u00FCz yorum yok.',
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
                        separatorBuilder: (_, __) =>
                            const Divider(color: AppColors.border, height: 14),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          await context.read<CommentThreadCubit>().create(
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
                        icon: const Icon(Icons.send, color: AppColors.coralAlt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    inputController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final statsKey = '${widget.targetType}:${widget.targetId}';
    final stats = context.watch<InteractionStatsCubit>().state.items[statsKey];
    final likeCount = stats?.likeCount ?? widget.initialLikeCount;
    final commentCount = stats?.commentCount ?? widget.initialCommentCount;
    final liked = stats?.isLiked ?? false;
    final likeLoading = stats?.loading ?? false;
    final preset = widget.framePreset;
    final Widget playerLayer;
    if (_playerController == null) {
      playerLayer = Center(
        child: Text(
          _playerError ?? 'Video yükleniyor...',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    } else if (preset != null && preset.verticalCrop) {
      playerLayer = LayoutBuilder(
        builder: (context, constraints) {
          final dx =
              preset.xNorm.clamp(-1.0, 1.0) * constraints.maxWidth * 0.45;
          final dy =
              preset.yNorm.clamp(-1.0, 1.0) * constraints.maxHeight * 0.45;
          final scale = preset.scale.clamp(1.0, 4.0);
          return ClipRect(
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: scale,
                child: BetterPlayer(controller: _playerController!),
              ),
            ),
          );
        },
      );
    } else {
      playerLayer = BetterPlayer(controller: _playerController!);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {
        _stopPlayback();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: isLandscape
                  ? playerLayer
                  : Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: playerLayer,
                      ),
                    ),
            ),
            Positioned(
              top: 46,
              left: 8,
              child: SafeArea(
                child: IconButton(
                  onPressed: () {
                    _stopPlayback();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 120,
              child: SafeArea(
                child: Column(
                  children: [
                    _ReelActionButton(
                      icon: liked ? Icons.favorite : Icons.favorite_border,
                      label: likeCount.toString(),
                      active: liked,
                      onTap: likeLoading
                          ? null
                          : () => context
                                .read<InteractionStatsCubit>()
                                .toggleLike(
                                  targetType: widget.targetType,
                                  targetId: widget.targetId,
                                ),
                    ),
                    const SizedBox(height: 14),
                    _ReelActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: commentCount.toString(),
                      onTap: _openCommentsSheet,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 80,
              bottom: 22,
              child: SafeArea(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ReelActionButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x55000000),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x66FFFFFF)),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.coralAlt : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
