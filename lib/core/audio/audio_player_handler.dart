import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  late final Stream<Duration> _positionStream = _player.createPositionStream(
    steps: 800,
    minPeriod: const Duration(milliseconds: 16),
    maxPeriod: const Duration(milliseconds: 50),
  );

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
  }) async {
    if (url.isEmpty) return;
    final baseItem = MediaItem(
      id: mediaId ?? url,
      title: title ?? 'Audio',
      duration: duration,
      extras: {'url': url},
    );
    mediaItem.add(baseItem);
    await _player.setUrl(url);
    final resolvedDuration = _player.duration ?? duration;
    mediaItem.add(baseItem.copyWith(duration: resolvedDuration));
    await _player.play();
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
