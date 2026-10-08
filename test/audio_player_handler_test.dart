import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/audio/audio_player_handler.dart';

void main() {
  group('replaceAudioSourceAtomically', () {
    test('publishes the candidate only after its source is ready', () async {
      final source = Completer<Duration?>();
      final published = <MediaItem?>[];
      var playCalls = 0;
      const next = MediaItem(id: 'next', title: 'Yeni kayıt');

      final operation = replaceAudioSourceAtomically(
        url: 'https://cdn.soundconnect.test/next.mp3',
        nextItem: next,
        previousItem: null,
        previousPosition: Duration.zero,
        previousWasPlaying: false,
        setUrl: (_) => source.future,
        seek: (_) async {},
        play: () async {
          playCalls += 1;
        },
        publish: published.add,
      );

      await Future<void>.delayed(Duration.zero);
      expect(published, isEmpty);

      source.complete(const Duration(minutes: 3));
      await operation;

      expect(published, hasLength(1));
      expect(published.single?.id, 'next');
      expect(published.single?.duration, const Duration(minutes: 3));
      expect(playCalls, 1);
    });

    test('restores the previous source when candidate loading fails', () async {
      const previous = MediaItem(
        id: 'previous',
        title: 'Önceki kayıt',
        extras: {'url': 'https://cdn.soundconnect.test/previous.mp3'},
      );
      const next = MediaItem(id: 'next', title: 'Yeni kayıt');
      final loadedUrls = <String>[];
      final published = <MediaItem?>[];
      final soughtPositions = <Duration>[];
      var playCalls = 0;

      final operation = replaceAudioSourceAtomically(
        url: 'https://cdn.soundconnect.test/broken.mp3',
        nextItem: next,
        previousItem: previous,
        previousPosition: const Duration(seconds: 42),
        previousWasPlaying: true,
        setUrl: (url) async {
          loadedUrls.add(url);
          if (url.endsWith('broken.mp3')) throw StateError('load failed');
          return const Duration(minutes: 2);
        },
        seek: (position) async {
          soughtPositions.add(position);
        },
        play: () async {
          playCalls += 1;
        },
        publish: published.add,
      );

      await expectLater(operation, throwsA(isA<StateError>()));

      expect(loadedUrls, [
        'https://cdn.soundconnect.test/broken.mp3',
        'https://cdn.soundconnect.test/previous.mp3',
      ]);
      expect(published, hasLength(1));
      expect(published.single, same(previous));
      expect(soughtPositions, [const Duration(seconds: 42)]);
      expect(playCalls, 1);
    });

    test(
      'clears stale metadata so a failed first load can be retried',
      () async {
        const next = MediaItem(id: 'next', title: 'Yeni kayıt');
        final published = <MediaItem?>[];
        var loadCalls = 0;
        var playCalls = 0;

        Future<Duration?> setUrl(String _) async {
          loadCalls += 1;
          if (loadCalls == 1) throw StateError('temporary failure');
          return const Duration(seconds: 90);
        }

        Future<void> load() => replaceAudioSourceAtomically(
          url: 'https://cdn.soundconnect.test/retry.mp3',
          nextItem: next,
          previousItem: published.isEmpty ? null : published.last,
          previousPosition: Duration.zero,
          previousWasPlaying: false,
          setUrl: setUrl,
          seek: (_) async {},
          play: () async {
            playCalls += 1;
          },
          publish: published.add,
        );

        await expectLater(load(), throwsA(isA<StateError>()));
        expect(published, hasLength(1));
        expect(published.single, isNull);

        await load();

        expect(loadCalls, 2);
        expect(published.last?.id, 'next');
        expect(published.last?.duration, const Duration(seconds: 90));
        expect(playCalls, 1);
      },
    );
  });

  group('AudioSourceMutationSequencer', () {
    test(
      'a never-completing playback does not block the next source mutation',
      () async {
        final sequencer = AudioSourceMutationSequencer();
        final firstPlayback = Completer<void>();
        var firstSourceStarted = false;
        var secondSourceStarted = false;
        var firstPublicCallCompleted = false;

        final firstCall = sequencer.run(() async {
          firstSourceStarted = true;
          return AudioPlaybackStart(firstPlayback.future);
        });
        unawaited(
          firstCall.then((_) {
            firstPublicCallCompleted = true;
          }),
        );
        await Future<void>.delayed(Duration.zero);

        final secondCall = sequencer.run(() async {
          secondSourceStarted = true;
          return AudioPlaybackStart(Future<void>.value());
        });
        await secondCall.timeout(const Duration(seconds: 1));

        expect(firstSourceStarted, isTrue);
        expect(secondSourceStarted, isTrue);
        expect(firstPublicCallCompleted, isFalse);

        firstPlayback.complete();
        await firstCall;
      },
    );
  });
}
