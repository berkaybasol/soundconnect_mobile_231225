import 'package:flutter/foundation.dart';

import 'network_config.dart';

/// Resolves backend-owned media references while keeping production transport
/// policy strict. Relative references inherit [NetworkConfig.baseUrl]. Media
/// must use HTTPS; this policy also applies when the API itself runs locally.
String? resolveAppMediaUrl(String? value) {
  return resolveMediaUrl(value, baseUri: Uri.tryParse(NetworkConfig.baseUrl));
}

@visibleForTesting
String? resolveMediaUrl(String? value, {required Uri? baseUri}) {
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
  return null;
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
