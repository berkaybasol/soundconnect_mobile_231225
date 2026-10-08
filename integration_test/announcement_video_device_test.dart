// Isolated Android decoder/component QA, never a normal application entry point.
// Run in debug with --dart-define=ANNOUNCEMENT_VIDEO_DEVICE_FIXTURE=true.
// The host serves the generated two-second MP4 on loopback:8092; the runner
// supplies adb reverse tcp:8092 tcp:8092. This file never contacts an API.
import 'dart:convert';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/video_playback_observations.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

const _fixtureUrl = 'http://127.0.0.1:8092/announcement-normalized.mp4';
const _fixtureLength = 410116;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('native Android announcement MP4 decoder and playback events', (
    tester,
  ) async {
    final report = <String, dynamic>{
      'scope': 'native_player_component_and_production_observation_helper',
      'preflight_passed': false,
      'passed': false,
      'checks': <String, bool>{},
      'limitations': [
        'Uses the installed BetterPlayer native decoder and production '
            'VideoPlaybackObservations helper, not VideoReelScreen navigation.',
        'Synthetic fixture bytes are fetched only from host loopback, then '
            'played through the plugin memory source and its temporary file.',
        'Does not test signed HTTPS URLs, authorization, CDN, renewal, '
            'analytics delivery, audio audibility, or admin preview attribution.',
        'This debug correctness check is not a profile performance benchmark.',
      ],
    };
    binding.reportData = report;
    final elapsed = Stopwatch()..start();
    final phases = <Map<String, Object?>>[];
    report['phases'] = phases;
    void phase(String name) {
      final marker = <String, Object?>{
        'name': name,
        'elapsed_ms': elapsed.elapsedMilliseconds,
        'lifecycle': binding.lifecycleState?.name,
      };
      phases.add(marker);
      debugPrintSynchronously('ANNOUNCEMENT_VIDEO_PHASE ${jsonEncode(marker)}');
    }

    // Preserve diagnostics even when a failed native test cannot return its
    // driver payload. This contains only the synthetic fixture and counters.
    addTearDown(() {
      debugPrintSynchronously(
        'ANNOUNCEMENT_VIDEO_REPORT ${jsonEncode(report)}',
      );
    });
    phase('preflight');
    const enabled = bool.fromEnvironment('ANNOUNCEMENT_VIDEO_DEVICE_FIXTURE');
    if (!enabled || !kDebugMode || !Platform.isAndroid) {
      throw StateError(
        'Run this isolated fixture on Android in debug with '
        '--dart-define=ANNOUNCEMENT_VIDEO_DEVICE_FIXTURE=true. '
        'No production transport policy is overridden.',
      );
    }
    report['preflight_passed'] = true;
    phase('fixture_download');
    final bytes = await tester.runAsync(_loadFixture);
    if (bytes == null) {
      throw StateError('The synthetic fixture download did not complete.');
    }
    report['fixture'] = {
      'url': _fixtureUrl,
      'bytes': bytes.length,
      'expected_duration_ms': 2000,
      'expected_width': 1152,
      'expected_height': 720,
      'source_codecs': 'H.264 yuv420p + AAC mono 48000 Hz (host FFprobe)',
    };

    final checks = report['checks'] as Map<String, bool>;
    final observations = VideoPlaybackObservations();
    final eventCounts = <String, int>{};
    final errors = <String>[];
    final distinctPositions = <int>{};
    var starts = 0;
    var completions = 0;
    var maximumPositionMs = 0;
    late final BetterPlayerController controller;

    void onEvent(BetterPlayerEvent event) {
      final type = event.betterPlayerEventType;
      eventCounts.update(type.name, (count) => count + 1, ifAbsent: () => 1);
      if (type == BetterPlayerEventType.exception) {
        errors.add('${event.parameters}');
      }
      if (type == BetterPlayerEventType.progress) {
        final position = event.parameters?['progress'];
        if (position is Duration &&
            binding.lifecycleState == AppLifecycleState.resumed &&
            controller.videoPlayerController?.value.isPlaying == true) {
          final milliseconds = position.inMilliseconds;
          distinctPositions.add(milliseconds);
          if (milliseconds > maximumPositionMs) {
            maximumPositionMs = milliseconds;
          }
          if (observations.progress(position: position, playing: true)) {
            starts++;
          }
        }
      }
      if (type == BetterPlayerEventType.finished &&
          binding.lifecycleState == AppLifecycleState.resumed &&
          observations.finished()) {
        completions++;
      }
      report['playback'] = {
        'events': eventCounts,
        'errors': errors,
        'start_callbacks': starts,
        'completion_callbacks': completions,
        'distinct_playing_positions': distinctPositions.length,
        'maximum_position_ms': maximumPositionMs,
      };
    }

    controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoDispose: false,
        autoPlay: false,
        // Announcements must reach the native terminal event. Legacy profile
        // reels retain their separate looping behavior in VideoReelScreen.
        looping: false,
        fit: BoxFit.cover,
        expandToFill: false,
        handleLifecycle: true,
        eventListener: onEvent,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
    );
    addTearDown(() async {
      phase('cleanup');
      controller.removeEventsListener(onEvent);
      try {
        if (controller.videoPlayerController != null) {
          await controller.pause().timeout(const Duration(seconds: 3));
        }
      } catch (error) {
        report['cleanup_pause_error'] = '$error';
      }
      // A live test pump waits for a frame. A locked/backgrounded phone may
      // never provide it, so cleanup must not depend on another rendered frame.
      controller.dispose(forceDispose: true);
    });
    phase('mount');
    runApp(
      MaterialApp(
        theme: AppTheme.navy,
        home: Scaffold(
          appBar: AppBar(title: const Text('Yerel video doğrulaması')),
          body: Center(
            child: AspectRatio(
              aspectRatio: 1152 / 720,
              child: BetterPlayer(controller: controller),
            ),
          ),
        ),
      ),
    );
    await _waitUntil(
      () =>
          binding.rootElement != null &&
          find.byType(BetterPlayer).evaluate().isNotEmpty,
      description: 'mounted native player surface',
    );
    _requireForeground();
    checks['foreground_before_native_playback'] = true;
    phase('native_setup');
    await controller
        .setupDataSource(
          BetterPlayerDataSource.memory(bytes, videoExtension: 'mp4'),
        )
        .timeout(const Duration(seconds: 20));
    final value = controller.videoPlayerController!.value;
    report['native_metadata'] = {
      'initialized': value.initialized,
      'duration_ms': value.duration?.inMilliseconds,
      'width': value.size?.width,
      'height': value.size?.height,
    };
    expect(value.initialized, isTrue);
    expect(value.duration?.inMilliseconds, closeTo(2000, 100));
    expect(value.size, const Size(1152, 720));
    expect(value.hasError, isFalse);
    checks['native_decoder_initialized_expected_fixture'] = true;
    phase('native_initialized');

    // Muted synthetic audio still exercises AAC track decoding. Audibility is
    // deliberately outside this check and is listed in the report.
    _requireForeground();
    await controller.setVolume(0).timeout(const Duration(seconds: 3));
    await controller.play().timeout(const Duration(seconds: 3));
    phase('first_playback');
    await _waitUntil(
      () => completions == 1 || errors.isNotEmpty,
      description: 'real native playback and terminal completion',
    );
    expect(errors, isEmpty);
    expect(starts, 1);
    expect(maximumPositionMs, greaterThan(1000));
    expect(distinctPositions.length, greaterThanOrEqualTo(2));
    expect(completions, 1);
    report['first_playback'] = {
      'raw_finished_events': eventCounts['finished'] ?? 0,
      'start_callbacks': starts,
      'completion_callbacks': completions,
    };
    checks['native_positive_progress_start_and_terminal_completion'] = true;

    // An explicit replay must reach another real native terminal event, while
    // the production observation helper retains one pair per opened playback.
    // No synthetic progress or finished events are injected in either pass.
    phase('explicit_replay');
    await controller.seekTo(Duration.zero).timeout(const Duration(seconds: 3));
    await controller.play().timeout(const Duration(seconds: 3));
    await _waitUntil(
      () => (eventCounts['finished'] ?? 0) >= 2 || errors.isNotEmpty,
      description: 'second native terminal completion after explicit replay',
    );
    await Future<void>.delayed(const Duration(milliseconds: 750));
    _requireForeground();
    expect(errors, isEmpty);
    expect(starts, 1);
    expect(completions, 1);
    expect(eventCounts['finished'], greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
    checks['explicit_replay_keeps_one_observation_pair'] = true;
    report['passed'] = true;
    phase('passed');
  });
}

Future<List<int>> _loadFixture() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..findProxy = (_) => 'DIRECT';
  try {
    final request = await client.getUrl(Uri.parse(_fixtureUrl));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok ||
        response.contentLength != _fixtureLength ||
        response.headers.contentType?.mimeType != 'video/mp4') {
      throw StateError('Expected the exact synthetic MP4 from loopback:8092.');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > _fixtureLength) {
        throw StateError(
          'Synthetic fixture exceeded its expected byte length.',
        );
      }
    }
    if (bytes.length != _fixtureLength ||
        String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
      throw StateError('Synthetic fixture is incomplete or not an MP4.');
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitUntil(
  bool Function() condition, {
  required String description,
}) async {
  final elapsed = Stopwatch()..start();
  _requireForeground();
  while (!condition() && elapsed.elapsed < const Duration(seconds: 15)) {
    // fullyLive already renders scheduled frames. Poll the real native event
    // loop independently so loss of foreground cannot strand a pending pump.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _requireForeground();
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for $description.');
}

void _requireForeground() {
  final state = WidgetsBinding.instance.lifecycleState;
  if (state != AppLifecycleState.resumed) {
    throw StateError(
      'Native playback verification requires an unlocked foreground app; '
      'observed lifecycle=${state?.name ?? 'unavailable'}. '
      'Paused progress does not count as playback.',
    );
  }
}
