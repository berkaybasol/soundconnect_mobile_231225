import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/simulation/local_simulation_config.dart';

void main() {
  group('local simulation safety boundary', () {
    test('is enabled only for an explicit debug request on a local origin', () {
      expect(
        resolveLocalSimulationEnabled(
          isDebugBuild: true,
          requested: true,
          baseUri: Uri.parse('http://127.0.0.1:8080'),
        ),
        isTrue,
      );
      expect(
        resolveLocalSimulationEnabled(
          isDebugBuild: true,
          requested: true,
          baseUri: Uri.parse('http://10.0.2.2:8080'),
        ),
        isTrue,
      );
      expect(
        resolveLocalSimulationEnabled(
          isDebugBuild: false,
          requested: true,
          baseUri: Uri.parse('https://localhost'),
        ),
        isFalse,
      );
      expect(
        resolveLocalSimulationEnabled(
          isDebugBuild: true,
          requested: false,
          baseUri: Uri.parse('http://localhost:8080'),
        ),
        isFalse,
      );
      expect(
        resolveLocalSimulationEnabled(
          isDebugBuild: true,
          requested: true,
          baseUri: Uri.parse('https://api.soundconnect.example'),
        ),
        isFalse,
      );
    });

    test('accepts only loopback and the Android emulator host bridge', () {
      for (final host in ['localhost', 'LOCALHOST', '127.0.0.1', '127.4.5.6', '::1', '10.0.2.2']) {
        expect(isLocalSimulationHost(host), isTrue, reason: host);
      }
      for (final host in ['127.0.0.999', '10.0.2.3', '192.168.1.10', 'example.com']) {
        expect(isLocalSimulationHost(host), isFalse, reason: host);
      }
    });

    test('observer catalog matches the deterministic backend manifest', () {
      expect(
        LocalSimulationConfig.musicianObservers
            .map((persona) => (persona.key, persona.username, persona.state))
            .toList(),
        const [
          (
            'musician-ist-01',
            'denizkaraca',
            LocalSimulationObserverState.complete,
          ),
          (
            'musician-ank-01',
            'eceaydin',
            LocalSimulationObserverState.incomplete,
          ),
          (
            'musician-bridge-01',
            'mertkoral',
            LocalSimulationObserverState.coldStart,
          ),
        ],
      );
    });
  });
}
