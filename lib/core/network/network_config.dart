class NetworkConfig {
  // Local-development fallback. Prefer overriding this in real environments:
  // flutter run --dart-define=SOUNDCONNECT_BASE_URL=http://host:port
  static const String defaultBaseUrl = 'http://192.168.1.111:8080';
  static const String baseUrl = String.fromEnvironment(
    'SOUNDCONNECT_BASE_URL',
    defaultValue: defaultBaseUrl,
  );
}
