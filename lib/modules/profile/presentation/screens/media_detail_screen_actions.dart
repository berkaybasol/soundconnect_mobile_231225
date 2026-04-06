part of 'media_detail_screen.dart';

extension _MediaDetailScreenActions on _MediaDetailScreenState {
  Future<void> _initVideo() async {
    if (!widget.isVideo) return;
    final url = (widget.playbackUrl ?? '').trim();
    if (url.isEmpty) {
      _updateState(() => _videoError = 'Video oynatma baglantisi bulunamadi.');
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _updateState(() {
        _videoController = controller;
        _videoReady = true;
        _videoError = null;
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _videoReady = false;
        _videoError = 'Video acilamadi. Lutfen tekrar dene.';
      });
    }
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
      } else if (isCurrent && !isPlaying) {
        await handler.play();
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
    final milliseconds = (duration.inMilliseconds * ratio)
        .round()
        .clamp(0, duration.inMilliseconds)
        .toInt();
    await serviceLocator<AudioHandler>().seek(
      Duration(milliseconds: milliseconds),
    );
  }

  Future<void> _seekRelativeSeconds(int deltaSeconds) async {
    final handler = serviceLocator<AudioHandler>();
    final duration = handler.mediaItem.value?.duration;
    final current = handler.playbackState.value.updatePosition;
    final maxMs = duration?.inMilliseconds ?? 0;
    final target = (current.inMilliseconds + (deltaSeconds * 1000))
        .clamp(0, maxMs > 0 ? maxMs : 1 << 30)
        .toInt();
    await handler.seek(Duration(milliseconds: target));
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
    _updateState(() {
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
}
