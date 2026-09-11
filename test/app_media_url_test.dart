import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/app_media_url.dart';

void main() {
  group('resolveMediaUrl', () {
    const capability = 'abcdefghijklmnopqrstuvwxyzABCDEFGH012345678';
    const debugSimulation = (
      isDebugBuild: true,
      isLocalSimulationEnabled: true,
    );

    String? resolve(
      String? value, {
      Uri? baseUri,
      bool? isDebugBuild,
      bool? isLocalSimulationEnabled,
    }) {
      return resolveMediaUrl(
        value,
        baseUri: baseUri ?? Uri.parse('http://10.0.2.2:8080'),
        isDebugBuild: isDebugBuild ?? debugSimulation.isDebugBuild,
        isLocalSimulationEnabled:
            isLocalSimulationEnabled ??
            debugSimulation.isLocalSimulationEnabled,
      );
    }

    test('resolves backend relative paths against the configured base URL', () {
      expect(
        resolve('/api/v1/public/simulation-media/$capability'),
        'http://10.0.2.2:8080/api/v1/public/simulation-media/$capability',
      );
      expect(
        resolve(
          'media/track.mp3?version=2',
          baseUri: Uri.parse('https://api.soundconnect.test/v1'),
          isDebugBuild: false,
          isLocalSimulationEnabled: false,
        ),
        'https://api.soundconnect.test/v1/media/track.mp3?version=2',
      );
    });

    test('allows HTTPS media in every build', () {
      expect(
        resolve(
          'https://cdn.soundconnect.test/media/photo.webp',
          isDebugBuild: false,
          isLocalSimulationEnabled: false,
        ),
        'https://cdn.soundconnect.test/media/photo.webp',
      );
    });

    test('allows HTTP only for local simulation in a debug build', () {
      const local =
          'http://127.0.0.1:8080/api/v1/public/simulation-media/$capability';
      final loopbackBase = Uri.parse('http://127.0.0.1:8080');
      expect(resolve(local, baseUri: loopbackBase), local);
      expect(
        resolve(local, baseUri: loopbackBase, isDebugBuild: false),
        isNull,
      );
      expect(
        resolve(local, baseUri: loopbackBase, isLocalSimulationEnabled: false),
        isNull,
      );
      expect(
        resolve(
          'http://10.0.2.2:8080/api/v1/public/simulation-media/$capability',
        ),
        isNotNull,
      );
      expect(
        resolve(
          'http://192.168.1.40:8080/api/v1/public/simulation-media/$capability',
        ),
        isNull,
      );
      expect(
        resolve(
          'http://media.example.com/api/v1/public/simulation-media/$capability',
        ),
        isNull,
      );
      expect(resolve('http://127.0.0.1:8080/private/media.png'), isNull);
      expect(resolve(local), isNull, reason: 'origin must match API origin');
      expect(
        resolve(
          'http://10.0.2.2:8081/api/v1/public/simulation-media/$capability',
        ),
        isNull,
        reason: 'port must match API origin',
      );
      expect(
        resolve(
          'http://10.0.2.2:8080/api/v1/public/simulation-media/$capability/extra',
        ),
        isNull,
      );
      expect(
        resolve(
          'http://10.0.2.2:8080/api/v1/public/simulation-media/$capability?token=x',
        ),
        isNull,
      );
    });

    test('rejects ambiguous or unsafe references', () {
      for (final value in [
        '//evil.example/media.png',
        'file:///tmp/media.png',
        'javascript:alert(1)',
        'https://user:secret@example.com/media.png',
        'https://example.com/media.png#fragment',
        r'..\media.png',
        '',
      ]) {
        expect(resolve(value), isNull, reason: value);
      }
    });
  });

  group('isSafeMediaReference', () {
    test('allows relative and HTTP(S) references for runtime validation', () {
      expect(isSafeMediaReference('/simulation/media/image.png'), isTrue);
      expect(isSafeMediaReference('media/audio.mp3'), isTrue);
      expect(
        isSafeMediaReference('https://cdn.example.test/image.png'),
        isTrue,
      );
      expect(isSafeMediaReference('http://localhost:8080/image.png'), isTrue);
      expect(isSafeMediaReference('//example.test/image.png'), isFalse);
    });
  });
}
