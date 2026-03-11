import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/waveform_stub.dart';

class MediaDetailScreen extends StatefulWidget {
  final String title;
  final bool isVideo;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
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
    required this.likeCount,
    required this.commentCount,
    this.isSpotify = false,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyTo;
  String? _replyMessage;
  Stream<Duration>? _positionStream;

  @override
  void dispose() {
    _commentFocusNode.dispose();
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
      body: Stack(
        children: [
          StreamBuilder<Duration>(
            stream: _positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final handler = serviceLocator<AudioHandler>();
              final currentId = handler.mediaItem.value?.id;
              final currentUrl =
                  handler.mediaItem.value?.extras?['url']?.toString();
              final isPlaying = handler.playbackState.value.playing;
              final isCurrent = widget.playbackUrl != null &&
                  (widget.playbackUrl == currentId ||
                      widget.playbackUrl == currentUrl);
              final totalSeconds = widget.isVideo || !isCurrent
                  ? 0
                  : (widget.durationSeconds ??
                      handler.mediaItem.value?.duration?.inSeconds ??
                      0);
              final progress = totalSeconds > 0
                  ? (position.inSeconds / totalSeconds).clamp(0.0, 1.0)
                  : 0.0;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  if (widget.isVideo)
                    _VideoHero(
                      thumbnailUrl: widget.thumbnailUrl,
                    )
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
                    likeCount: widget.likeCount,
                    commentCount: widget.commentCount,
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
                  _CommentBubble(
                    username: '@selin',
                    message: 'Harika enerji! Devam et.',
                    time: '2s',
                    likeCount: 12,
                    onReply: (message) {
                      setState(() {
                        _replyTo = '@selin';
                        _replyMessage = message;
                      });
                    },
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _CommentBubble(
                    username: '@emre',
                    message: 'Dalga formu cok iyi duruyor.',
                    time: '6s',
                    likeCount: 5,
                    onReply: (message) {
                      setState(() {
                        _replyTo = '@emre';
                        _replyMessage = message;
                      });
                    },
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _CommentBubble(
                    username: '@zeynep',
                    message: 'Bu parcanin devamini bekliyorum.',
                    time: '15s',
                    likeCount: 8,
                    onReply: (message) {
                      setState(() {
                        _replyTo = '@zeynep';
                        _replyMessage = message;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _CommentInput(
                    focusNode: _commentFocusNode,
                    replyTo: _replyTo,
                    replyMessage: _replyMessage,
                    onClearReply: () => setState(() {
                      _replyTo = null;
                      _replyMessage = null;
                    }),
                  ),
                ],
              );
            },
          ),
          if (_replyTo != null && _replyMessage != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() {
                  _replyTo = null;
                  _replyMessage = null;
                }),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxHeight: 420),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yanıtla $_replyTo',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _replyMessage!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: AppColors.border),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView(
                                children: const [
                                  _ReplyRow(username: '@melis', message: 'Efsane!'),
                                  _ReplyRow(username: '@tuna', message: 'Bunu sahnede dinlemek isterim.'),
                                  _ReplyRow(username: '@deniz', message: 'Tam playlistlik parca.'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                      focusNode: _commentFocusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Yanıtla $_replyTo',
                                        hintStyle: const TextStyle(color: AppColors.textMuted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {},
                                    icon: const Icon(Icons.send, color: AppColors.coralAlt),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          iconColor:
              isSpotify ? const Color(0xFF1DB954) : AppColors.coralAlt,
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

  const _CountRow({
    required this.likeCount,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.favorite_border, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          likeCount.toString(),
          style: const TextStyle(color: AppColors.textMuted),
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

class _CommentBubble extends StatefulWidget {
  final String username;
  final String message;
  final String time;
  final String? avatarUrl;
  final int likeCount;
  final ValueChanged<String>? onReply;

  const _CommentBubble({
    required this.username,
    required this.message,
    required this.time,
    this.avatarUrl,
    required this.likeCount,
    this.onReply,
  });

  @override
  State<_CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<_CommentBubble> {
  bool _liked = false;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.likeCount;
  }

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
            backgroundImage:
                widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
            child: widget.avatarUrl == null
                ? const Icon(Icons.person, size: 18, color: AppColors.textMuted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.message,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      widget.time,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => widget.onReply?.call(widget.message),
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
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _liked = !_liked;
                          _count += _liked ? 1 : -1;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            _liked
                                ? ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: AppColors.brandGradient,
                                        ).createShader(bounds),
                                    child: const Icon(
                                      Icons.favorite,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.favorite_border,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                            const SizedBox(width: 4),
                            Text(
                              _count.toString(),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
  final FocusNode focusNode;
  final String? replyTo;
  final String? replyMessage;
  final VoidCallback onClearReply;

  const _CommentInput({
    required this.focusNode,
    required this.replyTo,
    required this.replyMessage,
    required this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTo != null && replyMessage != null)
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yanıtlanıyor $replyTo',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          replyMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClearReply,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.sentiment_satisfied_alt,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText:
                        replyTo == null ? 'Yorum yaz...' : 'Yanıtla $replyTo',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.send, color: AppColors.coralAlt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyRow extends StatelessWidget {
  final String username;
  final String message;

  const _ReplyRow({
    required this.username,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.navBlueSoft,
            child: Icon(Icons.person, size: 12, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                children: [
                  TextSpan(
                    text: username,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(text: message),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
