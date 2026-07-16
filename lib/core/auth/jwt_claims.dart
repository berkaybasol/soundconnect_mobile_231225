import 'dart:convert';

class JwtClaims {
  final String? subject;
  final List<String> roles;
  final List<String> permissions;
  final DateTime expiresAt;

  const JwtClaims({
    required this.subject,
    required this.roles,
    required this.permissions,
    required this.expiresAt,
  });

  static JwtClaims? tryParse(
    String? token, {
    DateTime? now,
    Duration clockSkew = const Duration(seconds: 30),
  }) {
    final raw = token?.trim() ?? '';
    final parts = raw.split('.');
    if (raw.isEmpty || parts.length != 3) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;

      final expirationSeconds = _intValue(decoded['exp']);
      if (expirationSeconds == null || expirationSeconds <= 0) return null;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expirationSeconds * 1000,
        isUtc: true,
      );
      final effectiveNow = (now ?? DateTime.now()).toUtc();
      // Do not start requests with a token that will expire during transit.
      if (!expiresAt.isAfter(effectiveNow.add(clockSkew))) return null;

      final subject = decoded['sub']?.toString().trim();
      if (subject == null || subject.isEmpty) return null;

      return JwtClaims(
        subject: subject,
        roles: _stringList(
          decoded['roles'] ?? decoded['authorities'] ?? decoded['role'],
        ),
        permissions: _stringList(decoded['permissions']),
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
