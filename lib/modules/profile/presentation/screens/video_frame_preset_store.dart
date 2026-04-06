class VideoFramePreset {
  final double scale;
  final double xNorm;
  final double yNorm;
  final bool verticalCrop;

  const VideoFramePreset({
    required this.scale,
    required this.xNorm,
    required this.yNorm,
    required this.verticalCrop,
  });
}

class VideoFramePresetStore {
  static final Map<String, VideoFramePreset> _map =
      <String, VideoFramePreset>{};

  static VideoFramePreset? get(String mediaId) {
    final key = mediaId.trim();
    if (key.isEmpty) return null;
    return _map[key];
  }

  static void set(String mediaId, VideoFramePreset preset) {
    final key = mediaId.trim();
    if (key.isEmpty) return;
    _map[key] = preset;
  }

  static void remove(String mediaId) {
    final key = mediaId.trim();
    if (key.isEmpty) return;
    _map.remove(key);
  }
}
