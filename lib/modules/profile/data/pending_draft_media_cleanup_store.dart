import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pending_profile_upload_store.dart';

class PendingDraftMediaCleanup {
  const PendingDraftMediaCleanup({
    required this.sessionKey,
    required this.assetId,
    required this.ownerType,
    required this.ownerId,
    required this.createdAt,
  });

  final String sessionKey;
  final String assetId;
  final String ownerType;
  final String ownerId;
  final DateTime createdAt;

  String get key => '$sessionKey:$assetId';

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionKey': sessionKey,
    'assetId': assetId,
    'ownerType': ownerType,
    'ownerId': ownerId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static PendingDraftMediaCleanup? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sessionKey = value['sessionKey']?.toString().trim() ?? '';
    final assetId = value['assetId']?.toString().trim() ?? '';
    final ownerType = value['ownerType']?.toString().trim() ?? '';
    final ownerId = value['ownerId']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (sessionKey.isEmpty ||
        assetId.isEmpty ||
        ownerType.isEmpty ||
        ownerId.isEmpty ||
        createdAt == null) {
      return null;
    }
    return PendingDraftMediaCleanup(
      sessionKey: sessionKey,
      assetId: assetId,
      ownerType: ownerType,
      ownerId: ownerId,
      createdAt: createdAt.toUtc(),
    );
  }
}

abstract interface class PendingDraftMediaCleanupStore {
  Future<List<PendingDraftMediaCleanup>> readAll();

  Future<void> upsert(PendingDraftMediaCleanup pending);

  Future<void> remove(String key);
}

class SharedPreferencesPendingDraftMediaCleanupStore
    implements PendingDraftMediaCleanupStore {
  static const String _storageKey =
      'soundconnect.pending_draft_media_cleanup.v1';
  static const String _corruptStorageKey =
      'soundconnect.pending_draft_media_cleanup.v1.corrupt';
  static const int _envelopeVersion = 1;

  SharedPreferencesPendingDraftMediaCleanupStore({
    Future<PendingUploadPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader =
           preferencesLoader ??
           (() async => SharedPreferencesPendingUploadPreferences(
             await SharedPreferences.getInstance(),
           ));

  final Future<PendingUploadPreferences> Function() _preferencesLoader;
  final Map<String, PendingDraftMediaCleanup> _cache =
      <String, PendingDraftMediaCleanup>{};
  PendingUploadPreferences? _preferences;
  bool _loaded = false;
  Future<void> _tail = Future<void>.value();

  @override
  Future<List<PendingDraftMediaCleanup>> readAll() => _synchronized(() async {
    await _ensureLoaded();
    return List<PendingDraftMediaCleanup>.unmodifiable(_cache.values);
  });

  @override
  Future<void> upsert(PendingDraftMediaCleanup pending) =>
      _synchronized(() async {
        await _ensureLoaded();
        final previous = _cache[pending.key];
        _cache[pending.key] = pending;
        try {
          await _persist();
        } catch (_) {
          if (previous == null) {
            _cache.remove(pending.key);
          } else {
            _cache[pending.key] = previous;
          }
          rethrow;
        }
      });

  @override
  Future<void> remove(String key) => _synchronized(() async {
    await _ensureLoaded();
    final previous = _cache.remove(key);
    if (previous == null) return;
    try {
      await _persist();
    } catch (_) {
      _cache[key] = previous;
      rethrow;
    }
  });

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final PendingUploadPreferences preferences;
    try {
      preferences = await _preferencesLoader();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Draft cleanup preferences are unavailable',
          error,
        ),
        stackTrace,
      );
    }
    _preferences = preferences;
    final raw = preferences.getString(_storageKey);
    if (raw == null) {
      _loaded = true;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      final items = switch (decoded) {
        {'version': _envelopeVersion, 'items': final List<dynamic> values} =>
          values,
        _ => throw const FormatException('Invalid draft cleanup envelope'),
      };
      final loaded = <String, PendingDraftMediaCleanup>{};
      for (final item in items) {
        final normalized = item is Map ? Map<String, dynamic>.from(item) : null;
        final pending = PendingDraftMediaCleanup.fromJson(normalized);
        if (pending == null) {
          throw const FormatException('Invalid draft cleanup item');
        }
        loaded[pending.key] = pending;
      }
      _cache
        ..clear()
        ..addAll(loaded);
      _loaded = true;
    } on FormatException {
      await _quarantine(preferences, raw);
      _cache.clear();
      _loaded = true;
    } on TypeError {
      await _quarantine(preferences, raw);
      _cache.clear();
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) {
      throw const PendingUploadPersistenceException(
        'Draft cleanup preferences are unavailable',
      );
    }
    final payload = <String, Object?>{
      'version': _envelopeVersion,
      'items': _cache.values.map((item) => item.toJson()).toList(),
    };
    try {
      final persisted = await preferences.setString(
        _storageKey,
        jsonEncode(payload),
      );
      if (!persisted) {
        throw const PendingUploadPersistenceException(
          'Draft cleanup queue write was rejected',
        );
      }
    } on PendingUploadPersistenceException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Draft cleanup queue could not be written',
          error,
        ),
        stackTrace,
      );
    }
  }

  Future<void> _quarantine(
    PendingUploadPreferences preferences,
    String raw,
  ) async {
    try {
      await preferences.setString(_corruptStorageKey, raw);
    } catch (_) {
      // Best effort; removing the unreadable active queue is mandatory.
    }
    try {
      final removed = await preferences.remove(_storageKey);
      if (!removed) {
        throw const PendingUploadPersistenceException(
          'Corrupt draft cleanup queue could not be removed',
        );
      }
    } on PendingUploadPersistenceException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Corrupt draft cleanup queue could not be removed',
          error,
        ),
        stackTrace,
      );
    }
  }
}

class MemoryPendingDraftMediaCleanupStore
    implements PendingDraftMediaCleanupStore {
  MemoryPendingDraftMediaCleanupStore([
    Iterable<PendingDraftMediaCleanup> seed = const [],
  ]) {
    for (final pending in seed) {
      _items[pending.key] = pending;
    }
  }

  final Map<String, PendingDraftMediaCleanup> _items =
      <String, PendingDraftMediaCleanup>{};

  @override
  Future<List<PendingDraftMediaCleanup>> readAll() async =>
      List<PendingDraftMediaCleanup>.unmodifiable(_items.values);

  @override
  Future<void> remove(String key) async {
    _items.remove(key);
  }

  @override
  Future<void> upsert(PendingDraftMediaCleanup pending) async {
    _items[pending.key] = pending;
  }
}
