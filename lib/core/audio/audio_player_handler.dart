import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  late final Stream<Duration> _positionStream = _player.createPositionStream(
    steps: 800,
    minPeriod: const Duration(milliseconds: 16),
    maxPeriod: const Duration(milliseconds: 50),
  );
  final AudioSourceMutationSequencer _sourceMutations =
      AudioSourceMutationSequencer();

  AudioPlayerHandler() {
    _init();
  }

  Stream<Duration> get positionStream => _positionStream;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _transformProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _transformProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> playUrl(
    String url, {
    String? title,
    Duration? duration,
    String? mediaId,
  }) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) return Future<void>.value();
    return _sourceMutations.run(
      () => _playUrlNow(
        normalizedUrl,
        title: title,
        duration: duration,
        mediaId: mediaId,
      ),
    );
  }

  Future<AudioPlaybackStart> _playUrlNow(
    String url, {
    String? title,
    Duration? duration,
    String? mediaId,
  }) {
    final baseItem = MediaItem(
      id: mediaId ?? url,
      title: title ?? 'Audio',
      duration: duration,
      extras: {'url': url},
    );
    return replaceAudioSourceAtomically(
      url: url,
      nextItem: baseItem,
      previousItem: mediaItem.value,
      previousPosition: _player.position,
      previousWasPlaying: _player.playing,
      setUrl: _player.setUrl,
      seek: _player.seek,
      play: _player.play,
      publish: mediaItem.add,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

/// Commits audio metadata only after the source is ready. If loading fails,
/// the previous source is restored when possible; otherwise the published
/// item is cleared so the next tap performs a real URL load instead of trying
/// to play a stale source.
@visibleForTesting
Future<AudioPlaybackStart> replaceAudioSourceAtomically({
  required String url,
  required MediaItem nextItem,
  required MediaItem? previousItem,
  required Duration previousPosition,
  required bool previousWasPlaying,
  required Future<Duration?> Function(String url) setUrl,
  required Future<void> Function(Duration position) seek,
  required Future<void> Function() play,
  required void Function(MediaItem? item) publish,
}) async {
  try {
    final resolvedDuration = await setUrl(url);
    publish(nextItem.copyWith(duration: resolvedDuration ?? nextItem.duration));
  } catch (error, stackTrace) {
    final rollbackUrl = previousItem?.extras?['url'];
    var restored = false;
    if (rollbackUrl is String && rollbackUrl.trim().isNotEmpty) {
      try {
        await setUrl(rollbackUrl.trim());
        publish(previousItem);
        restored = true;
        try {
          await seek(previousPosition);
        } catch (_) {
          // A restored source remains usable even if its old position expired.
        }
        if (previousWasPlaying) {
          unawaited(_observedPlayback(play));
        }
      } catch (_) {
        // Clearing below prevents stale metadata from masquerading as loaded.
      }
    }
    if (!restored) publish(null);
    Error.throwWithStackTrace(error, stackTrace);
  }
  return AudioPlaybackStart(_observedPlayback(play));
}

/// Keeps source replacement operations ordered without holding the mutation
/// lock for the lifetime of playback. The returned future intentionally keeps
/// [AudioPlayerHandler.playUrl]'s existing playback-completion semantics.
@visibleForTesting
class AudioSourceMutationSequencer {
  Future<void> _tail = Future<void>.value();

  Future<void> run(
    Future<AudioPlaybackStart> Function() replaceSourceAndStartPlayback,
  ) {
    final sourceOperation = _tail.then((_) => replaceSourceAndStartPlayback());
    _tail = sourceOperation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return sourceOperation.then((started) => started.completion);
  }
}

@visibleForTesting
class AudioPlaybackStart {
  const AudioPlaybackStart(this.completion);

  final Future<void> completion;
}

Future<void> _observedPlayback(Future<void> Function() play) {
  late final Future<void> playback;
  try {
    playback = play();
  } catch (error, stackTrace) {
    playback = Future<void>.error(error, stackTrace);
  }
  // Callers may await the original future to retain playback-completion and
  // error semantics. This observer prevents an ignored playback future (for
  // example a rollback resume) from becoming an unhandled async error.
  unawaited(playback.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
  return playback;
}
