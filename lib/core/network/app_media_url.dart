import 'package:flutter/foundation.dart';

import '../simulation/local_simulation_config.dart';
import 'network_config.dart';

const String localSimulationMediaPathPrefix =
    '/api/v1/public/simulation-media/';

/// Resolves backend-owned media references while keeping production transport
/// policy strict. Relative references inherit [NetworkConfig.baseUrl]. Plain
/// HTTP is accepted only for an explicitly enabled local simulation running in
/// a debug build, and only on loopback or the Android emulator host bridge.
String? resolveAppMediaUrl(String? value) {
  return resolveMediaUrl(
    value,
    baseUri: Uri.tryParse(NetworkConfig.baseUrl),
    isDebugBuild: kDebugMode,
    isLocalSimulationEnabled: LocalSimulationConfig.isEnabled,
  );
}

@visibleForTesting
String? resolveMediaUrl(
  String? value, {
  required Uri? baseUri,
  required bool isDebugBuild,
  required bool isLocalSimulationEnabled,
}) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty || _containsUnsafeCharacters(raw)) {
    return null;
  }

  final parsed = Uri.tryParse(raw);
  if (parsed == null ||
      parsed.userInfo.isNotEmpty ||
      parsed.fragment.isNotEmpty) {
    return null;
  }

  late final Uri resolved;
  if (parsed.hasScheme) {
    resolved = parsed;
  } else {
    if (parsed.host.isNotEmpty || raw.startsWith('//') || baseUri == null) {
      return null;
    }
    final directoryBase = baseUri.replace(
      path: baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/',
      query: null,
      fragment: null,
    );
    resolved = directoryBase.resolveUri(parsed);
  }

  if (resolved.host.isEmpty || resolved.userInfo.isNotEmpty) return null;
  final scheme = resolved.scheme.toLowerCase();
  if (scheme == 'https') return resolved.toString();
  if (scheme != 'http' ||
      !isDebugBuild ||
      !isLocalSimulationEnabled ||
      !isLocalSimulationHost(resolved.host) ||
      baseUri == null ||
      resolved.hasQuery ||
      resolved.hasFragment ||
      !_isSimulationMediaCapabilityPath(resolved.path)) {
    return null;
  }
  if (_sameOrigin(resolved, baseUri)) return resolved.toString();
  if (!_canCanonicalizeLocalSimulationOrigin(resolved, baseUri)) {
    return null;
  }
  return Uri(
    scheme: baseUri.scheme.toLowerCase(),
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
    path: resolved.path,
  ).toString();
}

bool _canCanonicalizeLocalSimulationOrigin(Uri source, Uri base) {
  final baseScheme = base.scheme.toLowerCase();
  return baseScheme == source.scheme.toLowerCase() &&
      isLocalSimulationHost(base.host) &&
      base.userInfo.isEmpty &&
      !base.hasQuery &&
      !base.hasFragment &&
      (base.path.isEmpty || base.path == '/') &&
      _effectivePort(source) == _effectivePort(base);
}

bool _sameOrigin(Uri left, Uri right) {
  return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
      left.host.toLowerCase() == right.host.toLowerCase() &&
      _effectivePort(left) == _effectivePort(right);
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return switch (uri.scheme.toLowerCase()) {
    'http' => 80,
    'https' => 443,
    _ => -1,
  };
}

bool _isSimulationMediaCapabilityPath(String path) {
  if (!path.startsWith(localSimulationMediaPathPrefix)) return false;
  final capability = path.substring(localSimulationMediaPathPrefix.length);
  return RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(capability);
}

bool _containsUnsafeCharacters(String value) {
  return value.contains('\\') ||
      value.contains(RegExp(r'[\u0000-\u001F\u007F]'));
}

/// Syntax-only validation used at API parsing boundaries. Runtime transport
/// policy is applied by [resolveAppMediaUrl] when the resource is consumed.
bool isSafeMediaReference(String value) {
  final raw = value.trim();
  if (raw.isEmpty || _containsUnsafeCharacters(raw)) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty) {
    return false;
  }
  if (uri.hasScheme) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }
  return uri.host.isEmpty && !raw.startsWith('//');
}
