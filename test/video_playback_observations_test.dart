import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/video_playback_observations.dart';

void main() {
  test(
    'initialization, paused seek and early finished do not fabricate playback',
    () {
      final gate = VideoPlaybackObservations();
      expect(gate.finished(), isFalse);
      expect(gate.progress(position: Duration.zero, playing: true), isFalse);
      expect(
        gate.progress(position: const Duration(seconds: 25), playing: false),
        isFalse,
      );
      expect(gate.finished(), isFalse);
      expect(
        gate.progress(
          position: const Duration(milliseconds: 250),
          playing: true,
        ),
        isTrue,
      );
      expect(gate.finished(), isTrue);
    },
  );
  test(
    'loop/pause/resume emit one start and completion per opened playback',
    () {
      final gate = VideoPlaybackObservations();
      expect(
        gate.progress(position: const Duration(seconds: 1), playing: true),
        isTrue,
      );
      expect(
        gate.progress(position: const Duration(seconds: 5), playing: false),
        isFalse,
      );
      expect(
        gate.progress(position: const Duration(seconds: 6), playing: true),
        isFalse,
      );
      expect(gate.finished(), isTrue);
      expect(gate.finished(), isFalse);
      expect(
        gate.progress(position: const Duration(seconds: 1), playing: true),
        isFalse,
      );
      expect(gate.finished(), isFalse);
      expect(
        VideoPlaybackObservations().progress(
          position: const Duration(seconds: 1),
          playing: true,
        ),
        isTrue,
      );
    },
  );
}
