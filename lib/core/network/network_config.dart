import 'package:flutter/foundation.dart';

class NetworkConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'SOUNDCONNECT_BASE_URL',
    defaultValue: '',
  );
  static String get debugFallbackBaseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // USB debug default. Run `adb reverse tcp:8080 tcp:8080` before launching.
      return 'http://127.0.0.1:8080';
    }
    return 'http://localhost:8080';
  }

  static String get baseUrl => resolveNetworkBaseUrl(
    configuredBaseUrl: _configuredBaseUrl,
    isDebugBuild: kDebugMode,
    debugFallbackBaseUrl: debugFallbackBaseUrl,
  );
}

String resolveNetworkBaseUrl({
  required String configuredBaseUrl,
  required bool isDebugBuild,
  required String debugFallbackBaseUrl,
  bool allowDebugFallback = true,
}) {
  final String trimmed = configuredBaseUrl.trim();

  if (trimmed.isEmpty) {
    if (isDebugBuild && allowDebugFallback) {
      return debugFallbackBaseUrl;
    }
    throw StateError(
      'Missing SOUNDCONNECT_BASE_URL. Pass '
      '--dart-define=SOUNDCONNECT_BASE_URL=https://api.example.com',
    );
  }

  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    throw StateError('Invalid SOUNDCONNECT_BASE_URL: "$trimmed"');
  }

  if (!isDebugBuild && uri.scheme.toLowerCase() != 'https') {
    throw StateError(
      'Release builds require an HTTPS SOUNDCONNECT_BASE_URL, got: "$trimmed"',
    );
  }

  return trimmed;
}
