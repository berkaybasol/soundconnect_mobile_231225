import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'video_frame_preset_store.dart';

part 'video_reel_screen_actions.dart';

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

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

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
          _playerError ?? 'Video yukleniyor...',
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
