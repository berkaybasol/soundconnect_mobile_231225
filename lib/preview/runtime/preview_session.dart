import 'dart:convert';

import '../../core/auth/auth_session_manager.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/auth/token_store.dart';
import '../domain/preview_feed_scenario.dart';

/// Memory stores never instantiate platform secure storage or read an account.
class PreviewTokenStore implements TokenStore {
  String? _token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

class PreviewSessionStore implements AuthSessionStore {
  AuthSessionMetadata? _metadata;
  @override
  Future<AuthSessionMetadata?> read() async => _metadata;
  @override
  Future<void> write(AuthSessionMetadata metadata) async {
    _metadata = metadata;
  }

  @override
  Future<void> clear() async {
    _metadata = null;
  }
}

Future<AuthSessionManager> createPreviewSession() async {
  final sessions = AuthSessionManager(
    tokenStore: PreviewTokenStore(),
    sessionStore: PreviewSessionStore(),
  );
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  // Deliberately unsigned and marked as a local fixture; never a server token.
  final header = encode({'alg': 'none', 'typ': 'PREVIEW-ONLY'});
  final payload = encode({
    'sub': previewViewerUserId,
    'roles': ['ROLE_MUSICIAN'],
    'exp':
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/
        1000,
  });
  await sessions.startSession(
    token: '$header.$payload.preview-local-only',
    username: previewViewerUsername,
    accountStatus: 'ACTIVE',
  );
  return sessions;
}
