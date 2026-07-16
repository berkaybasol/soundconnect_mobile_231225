import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/network_config.dart';

void main() {
  group('resolveNetworkBaseUrl', () {
    test('uses debug fallback when value is empty', () {
      final String baseUrl = resolveNetworkBaseUrl(
        configuredBaseUrl: '',
        isDebugBuild: true,
        debugFallbackBaseUrl: 'http://localhost:8080',
      );

      expect(baseUrl, 'http://localhost:8080');
    });

    test('rejects empty value for non-debug builds', () {
      expect(
        () => resolveNetworkBaseUrl(
          configuredBaseUrl: '',
          isDebugBuild: false,
          debugFallbackBaseUrl: 'http://localhost:8080',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects invalid base url format', () {
      expect(
        () => resolveNetworkBaseUrl(
          configuredBaseUrl: 'not a valid url',
          isDebugBuild: true,
          debugFallbackBaseUrl: 'http://localhost:8080',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects non-https url in non-debug builds', () {
      expect(
        () => resolveNetworkBaseUrl(
          configuredBaseUrl: 'http://api.example.com',
          isDebugBuild: false,
          debugFallbackBaseUrl: 'http://localhost:8080',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('accepts https url in non-debug builds', () {
      final String baseUrl = resolveNetworkBaseUrl(
        configuredBaseUrl: 'https://api.example.com',
        isDebugBuild: false,
        debugFallbackBaseUrl: 'http://localhost:8080',
      );

      expect(baseUrl, 'https://api.example.com');
    });

    test('removes trailing slashes from configured and fallback urls', () {
      expect(
        resolveNetworkBaseUrl(
          configuredBaseUrl: 'https://api.example.com///',
          isDebugBuild: false,
          debugFallbackBaseUrl: 'http://localhost:8080/',
        ),
        'https://api.example.com',
      );
      expect(
        resolveNetworkBaseUrl(
          configuredBaseUrl: '',
          isDebugBuild: true,
          debugFallbackBaseUrl: 'http://localhost:8080/',
        ),
        'http://localhost:8080',
      );
    });

    test('can enforce explicit base url in debug mode', () {
      expect(
        () => resolveNetworkBaseUrl(
          configuredBaseUrl: '',
          isDebugBuild: true,
          debugFallbackBaseUrl: 'http://localhost:8080',
          allowDebugFallback: false,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
