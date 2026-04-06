import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';

part 'media_detail_screen_heroes.dart';
part 'media_detail_screen_heroes_audio.dart';
part 'media_detail_screen_comments.dart';
part 'media_detail_screen_actions.dart';

class MediaDetailScreen extends StatefulWidget {
  final String title;
  final bool isVideo;
  final bool isImage;
  final String? playbackUrl;
  final String? imageUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? targetType;
  final String? targetId;
  final int likeCount;
  final int commentCount;
  final bool isSpotify;

  const MediaDetailScreen({
    super.key,
    required this.title,
    required this.isVideo,
    this.isImage = false,
    this.playbackUrl,
    this.imageUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.targetType,
    this.targetId,
    required this.likeCount,
    required this.commentCount,
    this.isSpotify = false,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  final FocusNode _commentFocusNode = FocusNode();
  final TextEditingController _commentController = TextEditingController();
  Stream<Duration>? _positionStream;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  String? _videoError;

  String? _replyTo;
  String? _replyToCommentId;
  bool _initializedLoads = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _positionStream ??= serviceLocator<AudioHandler>() is AudioPlayerHandler
        ? (serviceLocator<AudioHandler>() as AudioPlayerHandler).positionStream
        : const Stream<Duration>.empty();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: StreamBuilder<Duration>(
        stream: _positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final handler = serviceLocator<AudioHandler>();
          final currentId = handler.mediaItem.value?.id;
          final currentUrl = handler.mediaItem.value?.extras?['url']
              ?.toString();
          final isPlaying = handler.playbackState.value.playing;
          final isCurrent =
              widget.playbackUrl != null &&
              (widget.playbackUrl == currentId ||
                  widget.playbackUrl == currentUrl);

          final totalMs = widget.isVideo || !isCurrent
              ? 0
              : ((widget.durationSeconds ?? 0) > 0
                    ? (widget.durationSeconds! * 1000)
                    : (handler.mediaItem.value?.duration?.inMilliseconds ?? 0));
          final progress = totalMs > 0
              ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
              : 0.0;

          final targetType = widget.targetType;
          final targetId = widget.targetId;
          final hasTarget =
              targetType != null &&
              targetType.isNotEmpty &&
              targetId != null &&
              targetId.isNotEmpty;

          if (hasTarget && !_initializedLoads) {
            _initializedLoads = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.read<InteractionStatsCubit>().load(
                targetType: targetType,
                targetId: targetId,
              );
              context.read<CommentThreadCubit>().load(
                targetType: targetType,
                targetId: targetId,
              );
            });
          }

          final stats = hasTarget
              ? context
                    .watch<InteractionStatsCubit>()
                    .state
                    .items['$targetType:$targetId']
              : null;
          final resolvedLikeCount = stats?.likeCount ?? widget.likeCount;
          final resolvedCommentCount =
              stats?.commentCount ?? widget.commentCount;
          final resolvedIsLiked = stats?.isLiked ?? false;
          final likeLoading = stats?.loading ?? false;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              if (widget.isVideo)
                _VideoHero(
                  controller: _videoController,
                  thumbnailUrl: widget.thumbnailUrl,
                  ready: _videoReady,
                  errorText: _videoError,
                )
              else if (widget.isImage)
                _ImageHero(imageUrl: widget.imageUrl)
              else
                _AudioHero(
                  title: widget.title,
                  isSpotify: widget.isSpotify,
                  playbackUrl: widget.playbackUrl,
                  onPlay: _togglePlayback,
                  onBack10: () => _seekRelativeSeconds(-10),
                  onForward10: () => _seekRelativeSeconds(10),
                  isPlaying: isCurrent && isPlaying,
                  progress: progress,
                  onSeek: _seekToRatio,
                ),
              const SizedBox(height: 16),
              _CountRow(
                likeCount: resolvedLikeCount,
                commentCount: resolvedCommentCount,
                liked: resolvedIsLiked,
                likeLoading: likeLoading,
                onLikeTap: !hasTarget
                    ? null
                    : () => context.read<InteractionStatsCubit>().toggleLike(
                        targetType: targetType,
                        targetId: targetId,
                      ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Yorumlar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              BlocBuilder<CommentThreadCubit, CommentThreadState>(
                builder: (context, commentState) {
                  if (!hasTarget) {
                    return const Text(
                      'Yorum hedefi bulunamadi.',
                      style: TextStyle(color: AppColors.textMuted),
                    );
                  }
                  if (commentState.loading && commentState.comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (commentState.comments.isEmpty) {
                    return const Text(
                      'Henuz yorum yok.',
                      style: TextStyle(color: AppColors.textMuted),
                    );
                  }
                  return Column(
                    children: List.generate(commentState.comments.length, (
                      index,
                    ) {
                      final item = commentState.comments[index];
                      return Column(
                        children: [
                          _CommentBubble(
                            comment: item,
                            timeLabel: _timeLabel(item.createdAt),
                            onReply: () {
                              setState(() {
                                _replyTo = '@${item.user.username}';
                                _replyToCommentId = item.id;
                              });
                            },
                          ),
                          if (index < commentState.comments.length - 1)
                            const Divider(color: AppColors.border, height: 16),
                        ],
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 18),
              _CommentInput(
                controller: _commentController,
                focusNode: _commentFocusNode,
                replyTo: _replyTo,
                submitting: context
                    .watch<CommentThreadCubit>()
                    .state
                    .submitting,
                onSend: _sendComment,
                onClearReply: () => setState(() {
                  _replyTo = null;
                  _replyToCommentId = null;
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
