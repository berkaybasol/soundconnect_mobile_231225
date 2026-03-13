import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';

class MediaDetailScreen extends StatefulWidget {
  final String title;
  final bool isVideo;
  final String? playbackUrl;
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
    this.playbackUrl,
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

  String? _replyTo;
  String? _replyToCommentId;
  bool _initializedLoads = false;

  @override
  void dispose() {
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final url = widget.playbackUrl;
    if (url == null || url.isEmpty) return;

    final handler = serviceLocator<AudioHandler>();
    final currentId = handler.mediaItem.value?.id;
    final currentUrl = handler.mediaItem.value?.extras?['url']?.toString();
    final isPlaying = handler.playbackState.value.playing;

    if (handler is AudioPlayerHandler) {
      final isCurrent = currentId == url || currentUrl == url;
      if (isCurrent && isPlaying) {
        await handler.pause();
      } else {
        final duration = widget.durationSeconds != null
            ? Duration(seconds: widget.durationSeconds!)
            : null;
        await handler.playUrl(url, title: widget.title, duration: duration);
      }
    }
  }

  Future<void> _seekToRatio(double ratio) async {
    final duration = serviceLocator<AudioHandler>().mediaItem.value?.duration;
    if (duration == null) return;
    final seconds =
        (duration.inSeconds * ratio).round().clamp(0, duration.inSeconds);
    await serviceLocator<AudioHandler>().seek(Duration(seconds: seconds));
  }

  Future<void> _sendComment() async {
    final targetType = widget.targetType;
    final targetId = widget.targetId;
    final text = _commentController.text.trim();
    if (targetType == null ||
        targetType.isEmpty ||
        targetId == null ||
        targetId.isEmpty ||
        text.isEmpty) {
      return;
    }

    await context.read<CommentThreadCubit>().create(
          targetType: targetType,
          targetId: targetId,
          text: text,
          parentCommentId: _replyToCommentId,
        );

    _commentController.clear();
    if (!mounted) return;
    setState(() {
      _replyTo = null;
      _replyToCommentId = null;
    });

    await context.read<InteractionStatsCubit>().load(
          targetType: targetType,
          targetId: targetId,
          force: true,
        );
  }

  String _timeLabel(DateTime? createdAt) {
    if (createdAt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'simdi';
    if (diff.inHours < 1) return '${diff.inMinutes}dk';
    if (diff.inDays < 1) return '${diff.inHours}s';
    return '${diff.inDays}g';
  }

  @override
  Widget build(BuildContext context) {
    _positionStream ??= serviceLocator<AudioHandler>() is AudioPlayerHandler
        ? (serviceLocator<AudioHandler>() as AudioPlayerHandler).positionStream
        : const Stream<Duration>.empty();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: StreamBuilder<Duration>(
        stream: _positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final handler = serviceLocator<AudioHandler>();
          final currentId = handler.mediaItem.value?.id;
          final currentUrl = handler.mediaItem.value?.extras?['url']?.toString();
          final isPlaying = handler.playbackState.value.playing;
          final isCurrent = widget.playbackUrl != null &&
              (widget.playbackUrl == currentId || widget.playbackUrl == currentUrl);

          final totalSeconds = widget.isVideo || !isCurrent
              ? 0
              : (widget.durationSeconds ??
                  handler.mediaItem.value?.duration?.inSeconds ??
                  0);
          final progress = totalSeconds > 0
              ? (position.inSeconds / totalSeconds).clamp(0.0, 1.0)
              : 0.0;

          final targetType = widget.targetType;
          final targetId = widget.targetId;
          final hasTarget = targetType != null &&
              targetType.isNotEmpty &&
              targetId != null &&
              targetId.isNotEmpty;

              if (hasTarget && !_initializedLoads) {
                _initializedLoads = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.read<InteractionStatsCubit>().load(
                    targetType: targetType!,
                    targetId: targetId!,
                  );
                  context.read<CommentThreadCubit>().load(
                    targetType: targetType!,
                    targetId: targetId!,
                  );
                });
              }

          final stats = hasTarget
              ? context.watch<InteractionStatsCubit>().state.items[
                  '$targetType:$targetId']
              : null;
          final resolvedLikeCount = stats?.likeCount ?? widget.likeCount;
          final resolvedCommentCount = stats?.commentCount ?? widget.commentCount;
          final resolvedIsLiked = stats?.isLiked ?? false;
          final likeLoading = stats?.loading ?? false;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              if (widget.isVideo)
                _VideoHero(thumbnailUrl: widget.thumbnailUrl)
              else
                _AudioHero(
                  title: widget.title,
                  isSpotify: widget.isSpotify,
                  playbackUrl: widget.playbackUrl,
                  onPlay: _togglePlayback,
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
                          targetType: targetType!,
                          targetId: targetId!,
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
                    children: List.generate(commentState.comments.length, (index) {
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
                submitting: context.watch<CommentThreadCubit>().state.submitting,
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

class _VideoHero extends StatelessWidget {
  final String? thumbnailUrl;

  const _VideoHero({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        image: thumbnailUrl != null
            ? DecorationImage(
                image: NetworkImage(thumbnailUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_fill,
          size: 64,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _AudioHero extends StatelessWidget {
  final String title;
  final bool isSpotify;
  final String? playbackUrl;
  final VoidCallback onPlay;
  final bool isPlaying;
  final double progress;
  final ValueChanged<double> onSeek;

  const _AudioHero({
    required this.title,
    required this.isSpotify,
    required this.playbackUrl,
    required this.onPlay,
    required this.isPlaying,
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        WaveformStub(
          gradientColors: isSpotify
              ? const [
                  Color(0xFF1ED760),
                  Color(0xFF1DB954),
                  Color(0xFF18A34A),
                ]
              : AppColors.brandGradient,
          iconColor: isSpotify ? const Color(0xFF1DB954) : AppColors.coralAlt,
          playIconColor:
              isSpotify ? const Color(0xFF1DB954) : AppColors.textMuted,
          leading: isSpotify
              ? const Icon(
                  FontAwesomeIcons.spotify,
                  size: 16,
                  color: Color(0xFF1DB954),
                )
              : Image.asset(
                  'assets/logo.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                ),
          height: 92,
          waveformHeight: 44,
          onPlay: playbackUrl == null || playbackUrl!.isEmpty ? null : onPlay,
          isPlaying: isPlaying,
          progress: progress,
          onSeek: onSeek,
        ),
      ],
    );
  }
}

class _CountRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool likeLoading;
  final VoidCallback? onLikeTap;

  const _CountRow({
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.likeLoading,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: likeLoading ? null : onLikeTap,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: liked ? AppColors.coralAlt : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.chat_bubble_outline,
            size: 18, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          commentCount.toString(),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final CommentItem comment;
  final String timeLabel;
  final VoidCallback onReply;

  const _CommentBubble({
    required this.comment,
    required this.timeLabel,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.navBlueSoft,
            backgroundImage: comment.user.avatarUrl != null
                ? NetworkImage(comment.user.avatarUrl!)
                : null,
            child: comment.user.avatarUrl == null
                ? const Icon(Icons.person, size: 18, color: AppColors.textMuted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${comment.user.username}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Yanitla',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyTo;
  final bool submitting;
  final VoidCallback onSend;
  final VoidCallback onClearReply;

  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.submitting,
    required this.onSend,
    required this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyTo != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.navBlueSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Yanitlaniyor $replyTo',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClearReply,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.navBlueSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.sentiment_satisfied_alt,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: replyTo == null ? 'Yorum yaz...' : 'Yanitla $replyTo',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: submitting ? null : onSend,
                icon: Icon(
                  Icons.send,
                  color: submitting ? AppColors.textMuted : AppColors.coralAlt,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
