import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/jwt_claims.dart';
import '../../../core/auth/token_store.dart';

class CollabIdempotencyLease {
  const CollabIdempotencyLease({
    required this.requestId,
    required this.storageKey,
    required this.createdAt,
  });

  final String requestId;
  final String storageKey;
  final DateTime createdAt;
}

class CollabIdempotencyStoreException implements Exception {
  const CollabIdempotencyStoreException(this.message);

  final String message;

  @override
  String toString() => 'CollabIdempotencyStoreException: $message';
}

abstract class CollabIdempotencyStore {
  Future<CollabIdempotencyLease> acquire({
    required String operation,
    required String targetId,
    required String payloadFingerprint,
    required String Function() createRequestId,
  });

  Future<void> complete(CollabIdempotencyLease lease);

  /// Clears the exact pending attempt when the user intentionally abandons it.
  Future<void> abandon(CollabIdempotencyLease lease);

  /// Starts a new logical operation for a stable operation/target pair. This
  /// must only be called for an explicit user reset, never on process startup.
  Future<void> resetOperation({
    required String operation,
    required String targetId,
  });
}

/// Production idempotency storage. Only hashes of the user scope, operation,
/// target and payload are persisted; private form values never reach prefs.
class SharedPreferencesCollabIdempotencyStore
    implements CollabIdempotencyStore {
  SharedPreferencesCollabIdempotencyStore({
    required TokenStore tokenStore,
    Future<SharedPreferences> Function()? preferencesLoader,
    this.leaseTtl = const Duration(hours: 24),
    DateTime Function()? clock,
  }) : _tokenStore = tokenStore,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now,
       assert(leaseTtl > Duration.zero);

  static const String _keyPrefix = 'sc_collab_idempotency_v1';

  final TokenStore _tokenStore;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Duration leaseTtl;
  final DateTime Function() _clock;
  final Map<String, Future<CollabIdempotencyLease>> _inFlight =
      <String, Future<CollabIdempotencyLease>>{};

  @override
  Future<CollabIdempotencyLease> acquire({
    required String operation,
    required String targetId,
    required String payloadFingerprint,
    required String Function() createRequestId,
  }) async {
    final userId = await _currentUserId();
    final normalizedOperation = operation.trim();
    final normalizedTarget = targetId.trim();
    if (normalizedOperation.isEmpty || normalizedTarget.isEmpty) {
      throw const CollabIdempotencyStoreException(
        'Operation and target are required.',
      );
    }
    final storageKey = _storageKey(
      userId: userId,
      operation: normalizedOperation,
      targetId: normalizedTarget,
    );
    final existing = _inFlight[storageKey];
    if (existing != null) return existing;

    final future = _acquireStored(
      storageKey: storageKey,
      payloadHash: _digest(payloadFingerprint),
      createRequestId: createRequestId,
    );
    _inFlight[storageKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[storageKey], future)) {
        _inFlight.remove(storageKey);
      }
    }
  }

  Future<CollabIdempotencyLease> _acquireStored({
    required String storageKey,
    required String payloadHash,
    required String Function() createRequestId,
  }) async {
    final preferences = await _preferencesLoader();
    final stored = _decodeEntry(preferences.getString(storageKey));
    final now = _clock().toUtc();
    if (stored != null &&
        stored.payloadHash == payloadHash &&
        _isReusable(stored, now)) {
      return CollabIdempotencyLease(
        requestId: stored.requestId,
        storageKey: storageKey,
        createdAt: stored.createdAt,
      );
    }

    final requestId = createRequestId().trim();
    if (requestId.isEmpty) {
      throw const CollabIdempotencyStoreException(
        'Request id factory returned an empty value.',
      );
    }
    final persisted = await preferences.setString(
      storageKey,
      jsonEncode(<String, Object>{
        'requestId': requestId,
        'payloadHash': payloadHash,
        'createdAt': now.toIso8601String(),
      }),
    );
    if (!persisted) {
      throw const CollabIdempotencyStoreException(
        'Idempotency key could not be persisted.',
      );
    }
    return CollabIdempotencyLease(
      requestId: requestId,
      storageKey: storageKey,
      createdAt: now,
    );
  }

  @override
  Future<void> complete(CollabIdempotencyLease lease) => abandon(lease);

  @override
  Future<void> abandon(CollabIdempotencyLease lease) async {
    final preferences = await _preferencesLoader();
    final stored = _decodeEntry(preferences.getString(lease.storageKey));
    if (stored == null || stored.requestId != lease.requestId) return;
    final removed = await preferences.remove(lease.storageKey);
    if (!removed) {
      throw const CollabIdempotencyStoreException(
        'Completed idempotency key could not be cleared.',
      );
    }
  }

  @override
  Future<void> resetOperation({
    required String operation,
    required String targetId,
  }) async {
    final normalizedOperation = operation.trim();
    final normalizedTarget = targetId.trim();
    if (normalizedOperation.isEmpty || normalizedTarget.isEmpty) {
      throw const CollabIdempotencyStoreException(
        'Operation and target are required.',
      );
    }
    final storageKey = _storageKey(
      userId: await _currentUserId(),
      operation: normalizedOperation,
      targetId: normalizedTarget,
    );
    final preferences = await _preferencesLoader();
    if (!preferences.containsKey(storageKey)) return;
    final removed = await preferences.remove(storageKey);
    if (!removed) {
      throw const CollabIdempotencyStoreException(
        'Idempotency operation could not be reset.',
      );
    }
  }

  Future<String> _currentUserId() async {
    final claims = JwtClaims.tryParse(await _tokenStore.readToken());
    final userId = claims?.subject?.trim() ?? '';
    if (userId.isEmpty) {
      throw const CollabIdempotencyStoreException(
        'An authenticated user scope is required.',
      );
    }
    return userId;
  }

  _StoredIdempotencyEntry? _decodeEntry(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final requestId = decoded['requestId']?.toString().trim() ?? '';
      final payloadHash = decoded['payloadHash']?.toString().trim() ?? '';
      final createdAtRaw = decoded['createdAt']?.toString().trim() ?? '';
      final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
      if (requestId.isEmpty || payloadHash.isEmpty || createdAt == null) {
        return null;
      }
      return _StoredIdempotencyEntry(
        requestId: requestId,
        payloadHash: payloadHash,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isReusable(_StoredIdempotencyEntry entry, DateTime now) {
    final age = now.difference(entry.createdAt);
    return !age.isNegative && age < leaseTtl;
  }

  String _storageKey({
    required String userId,
    required String operation,
    required String targetId,
  }) => '$_keyPrefix.${_digest('$userId|$operation|$targetId')}';

  String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
}

/// Deterministic test double. Reuse the same instance to simulate a process
/// restart while retaining the persisted request lease.
class MemoryCollabIdempotencyStore implements CollabIdempotencyStore {
  MemoryCollabIdempotencyStore({
    this.scope = 'memory-user',
    this.leaseTtl = const Duration(hours: 24),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       assert(leaseTtl > Duration.zero);

  final String scope;
  final Duration leaseTtl;
  final DateTime Function() _clock;
  final Map<String, _StoredIdempotencyEntry> _entries =
      <String, _StoredIdempotencyEntry>{};

  @override
  Future<CollabIdempotencyLease> acquire({
    required String operation,
    required String targetId,
    required String payloadFingerprint,
    required String Function() createRequestId,
  }) async {
    final storageKey = '$scope|${operation.trim()}|${targetId.trim()}';
    final payloadHash = sha256
        .convert(utf8.encode(payloadFingerprint))
        .toString();
    final existing = _entries[storageKey];
    final now = _clock().toUtc();
    final age = existing == null ? null : now.difference(existing.createdAt);
    if (existing != null &&
        existing.payloadHash == payloadHash &&
        age != null &&
        !age.isNegative &&
        age < leaseTtl) {
      return CollabIdempotencyLease(
        requestId: existing.requestId,
        storageKey: storageKey,
        createdAt: existing.createdAt,
      );
    }
    final requestId = createRequestId().trim();
    if (requestId.isEmpty) {
      throw const CollabIdempotencyStoreException(
        'Request id factory returned an empty value.',
      );
    }
    _entries[storageKey] = _StoredIdempotencyEntry(
      requestId: requestId,
      payloadHash: payloadHash,
      createdAt: now,
    );
    return CollabIdempotencyLease(
      requestId: requestId,
      storageKey: storageKey,
      createdAt: now,
    );
  }

  @override
  Future<void> complete(CollabIdempotencyLease lease) => abandon(lease);

  @override
  Future<void> abandon(CollabIdempotencyLease lease) async {
    final stored = _entries[lease.storageKey];
    if (stored?.requestId == lease.requestId) {
      _entries.remove(lease.storageKey);
    }
  }

  @override
  Future<void> resetOperation({
    required String operation,
    required String targetId,
  }) async {
    _entries.remove('$scope|${operation.trim()}|${targetId.trim()}');
  }
}

class _StoredIdempotencyEntry {
  const _StoredIdempotencyEntry({
    required this.requestId,
    required this.payloadHash,
    required this.createdAt,
  });

  final String requestId;
  final String payloadHash;
  final DateTime createdAt;
}
