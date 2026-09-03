import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSessionMetadata {
  static const int currentSchemaVersion = 2;

  final String? username;
  final String? accountStatus;
  final bool requiresListenerProfileChoice;
  final bool hasListenerProfileChoiceMarker;

  const AuthSessionMetadata({
    this.username,
    this.accountStatus,
    this.requiresListenerProfileChoice = false,
    bool? hasListenerProfileChoiceMarker,
  }) : hasListenerProfileChoiceMarker = hasListenerProfileChoiceMarker ?? true;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': currentSchemaVersion,
    'username': username,
    'accountStatus': accountStatus,
    'requiresListenerProfileChoice': requiresListenerProfileChoice,
  };

  factory AuthSessionMetadata.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final rawChoiceMarker = json['requiresListenerProfileChoice'];
    final hasValidChoiceMarker =
        version == currentSchemaVersion && rawChoiceMarker is bool;
    return AuthSessionMetadata(
      username: json['username']?.toString(),
      accountStatus: json['accountStatus']?.toString(),
      requiresListenerProfileChoice: rawChoiceMarker == true,
      hasListenerProfileChoiceMarker: hasValidChoiceMarker,
    );
  }
}

abstract class AuthSessionStore {
  Future<AuthSessionMetadata?> read();
  Future<void> write(AuthSessionMetadata metadata);
  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  static const _key = 'sc_auth_session_v1';
  final FlutterSecureStorage _storage;

  const SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<AuthSessionMetadata?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSessionMetadata.fromJson(decoded);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSessionMetadata metadata) {
    return _storage.write(key: _key, value: jsonEncode(metadata.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
