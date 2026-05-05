import 'dart:convert';

import '../../../core/auth/token_store.dart';

Future<String?> resolveNotificationUserId(TokenStore tokenStore) async {
  final token = await readNotificationAuthToken(tokenStore);
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final map = jsonDecode(payload);
    if (map is! Map<String, dynamic>) return null;
    final candidates = <String?>[
      map['userId']?.toString(),
      map['uid']?.toString(),
      map['id']?.toString(),
      map['sub']?.toString(),
    ];
    for (final value in candidates) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
  } catch (_) {}
  return null;
}

Future<String?> readNotificationAuthToken(TokenStore tokenStore) async {
  final token = (await tokenStore.readToken())?.trim() ?? '';
  return token.isEmpty ? null : token;
}
