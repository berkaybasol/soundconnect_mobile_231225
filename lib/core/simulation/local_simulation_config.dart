import 'package:flutter/foundation.dart';

import '../network/network_config.dart';

enum LocalSimulationObserverState { complete, incomplete, coldStart }

@immutable
class LocalSimulationPersona {
  const LocalSimulationPersona({
    required this.key,
    required this.username,
    required this.displayName,
    required this.state,
    required this.description,
  });

  final String key;
  final String username;
  final String displayName;
  final LocalSimulationObserverState state;
  final String description;
}

/// Compile-time switches for the disposable local simulation world.
///
/// The common password is deliberately neither persisted nor logged. Supply it
/// from an untracked IDE run configuration or on the command line with
/// `--dart-define=SOUNDCONNECT_SIMULATION_PASSWORD=...`. If it is omitted, the
/// persona picker asks for it each time.
class LocalSimulationConfig {
  LocalSimulationConfig._();

  static const bool _requested = bool.fromEnvironment(
    'SOUNDCONNECT_LOCAL_SIMULATION',
  );
  static const String _configuredPassword = String.fromEnvironment(
    'SOUNDCONNECT_SIMULATION_PASSWORD',
  );

  static bool get isEnabled {
    if (!kDebugMode || !_requested) return false;
    return isLocalSimulationOrigin(Uri.tryParse(NetworkConfig.baseUrl));
  }

  static String get commonPassword => isEnabled ? _configuredPassword : '';

  static const List<LocalSimulationPersona> musicianObservers = [
    LocalSimulationPersona(
      key: 'musician-ist-01',
      username: 'denizkaraca',
      displayName: 'Deniz Karaca',
      state: LocalSimulationObserverState.complete,
      description: 'Tam profil ve olgun takip ağı',
    ),
    LocalSimulationPersona(
      key: 'musician-ank-01',
      username: 'eceaydin',
      displayName: 'Ece Aydın',
      state: LocalSimulationObserverState.incomplete,
      description: 'Eksik profil ve tamamlama kartı',
    ),
    LocalSimulationPersona(
      key: 'musician-bridge-01',
      username: 'mertkoral',
      displayName: 'Mert Koral',
      state: LocalSimulationObserverState.coldStart,
      description: 'Takipsiz soğuk başlangıç',
    ),
  ];
}

@visibleForTesting
bool resolveLocalSimulationEnabled({
  required bool isDebugBuild,
  required bool requested,
  required Uri? baseUri,
}) {
  return isDebugBuild && requested && isLocalSimulationOrigin(baseUri);
}

@visibleForTesting
bool isLocalSimulationOrigin(Uri? uri) {
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  return isLocalSimulationHost(uri.host);
}

bool isLocalSimulationHost(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized == 'localhost' ||
      normalized == '::1' ||
      normalized == '10.0.2.2') {
    return true;
  }
  final ipv4 = RegExp(r'^127(?:\.\d{1,3}){3}$').firstMatch(normalized);
  if (ipv4 == null) return false;
  return normalized
      .split('.')
      .skip(1)
      .every((part) => (int.tryParse(part) ?? 256) <= 255);
}
