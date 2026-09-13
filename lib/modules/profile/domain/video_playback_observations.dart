/// One start/end pair per opened playback. A seek while paused, initialization,
/// buffering or a plugin's early finished event is not a playback start.
class VideoPlaybackObservations {
  bool _started = false;
  bool _completed = false;

  bool progress({required Duration position, required bool playing}) {
    if (_started || !playing || position <= Duration.zero) return false;
    _started = true;
    return true;
  }

  bool finished() {
    if (!_started || _completed) return false;
    _completed = true;
    return true;
  }
}
