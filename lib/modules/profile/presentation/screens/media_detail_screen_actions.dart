part of 'media_detail_screen.dart';

extension _MediaDetailScreenActions on _MediaDetailScreenState {
  Future<void> _initVideo() async {
    final attempt = ++_videoAttempt;
    final isVideo = widget.isVideo;
    final url = resolveAppMediaUrl(widget.playbackUrl);
    final previous = _videoController;
    _updateState(() {
      _videoError = isVideo && url == null
          ? 'Video oynatma bağlantısı bulunamadı. Lütfen tekrar dene.'
          : null;
      _videoController = null;
    });
    await previous?.dispose();
    if (!mounted || attempt != _videoAttempt || !isVideo || url == null) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    // Own the pending controller too: retry, a new target and dispose must all
    // invalidate this attempt before any asynchronous completion can affect UI.
    _updateState(() => _videoController = controller);
    try {
      await controller.initialize();
      if (!mounted ||
          attempt != _videoAttempt ||
          !identical(_videoController, controller) ||
          controller.value.hasError) {
        return;
      }
      await controller.setLooping(true);
    } catch (_) {
      if (!mounted ||
          attempt != _videoAttempt ||
          !identical(_videoController, controller)) {
        return;
      }
      _updateState(() {
        _videoError = 'Video açılamadı. Lütfen tekrar dene.';
      });
    }
  }

  Future<void> _prepareNotificationAudio() async {
    if (widget.notificationContent == null ||
        widget.isImage ||
        widget.isVideo) {
      return;
    }
    final url = resolveAppMediaUrl(widget.playbackUrl);
    final player = audio.AudioPlayer();
    final previous = _audioProbe;
    _audioProbe = player;
    _updateState(() {
      _audioReady = false;
      _audioError = null;
    });
    await previous?.dispose();
    try {
      if (url == null) throw StateError('Missing media URL');
      await player.setUrl(url);
      if (!mounted || !identical(_audioProbe, player)) return;
      _updateState(() => _audioReady = true);
    } catch (_) {
      if (!mounted || !identical(_audioProbe, player)) return;
      _updateState(() => _audioError = 'Ses yüklenemedi. İçeriği tekrar yükle');
    }
  }

  Future<void> _togglePlayback() async {
    final url = resolveAppMediaUrl(widget.playbackUrl);
    if (url == null) return;

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
}
