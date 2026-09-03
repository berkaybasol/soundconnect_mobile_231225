import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile_media_upload_repository.dart';

enum PendingProfileUploadPhase { uploading, verifying, attaching }

class PendingProfileUpload {
  final String sessionKey;
  final String assetId;
  final String ownerType;
  final String ownerId;
  final String mediaKind;
  final DateTime deadline;
  final int retryIndex;
  final PendingProfileUploadPhase phase;
  final ProfileUploadAttachmentIntent attachmentIntent;
  final String? completedMediaId;
  final String? sourceUrl;
  final String? playbackUrl;

  const PendingProfileUpload({
    required this.sessionKey,
    required this.assetId,
    required this.ownerType,
    required this.ownerId,
    required this.mediaKind,
    required this.deadline,
    required this.retryIndex,
    required this.phase,
    required this.attachmentIntent,
    this.completedMediaId,
    this.sourceUrl,
    this.playbackUrl,
  });

  String get key => '$sessionKey:$assetId';

  PendingProfileUpload copyWith({
    DateTime? deadline,
    int? retryIndex,
    PendingProfileUploadPhase? phase,
    String? completedMediaId,
    String? sourceUrl,
    String? playbackUrl,
  }) {
    return PendingProfileUpload(
      sessionKey: sessionKey,
      assetId: assetId,
      ownerType: ownerType,
      ownerId: ownerId,
      mediaKind: mediaKind,
      deadline: deadline ?? this.deadline,
      retryIndex: retryIndex ?? this.retryIndex,
      phase: phase ?? this.phase,
      attachmentIntent: attachmentIntent,
      completedMediaId: completedMediaId ?? this.completedMediaId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      playbackUrl: playbackUrl ?? this.playbackUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionKey': sessionKey,
    'assetId': assetId,
    'ownerType': ownerType,
    'ownerId': ownerId,
    'mediaKind': mediaKind,
    'deadline': deadline.toUtc().toIso8601String(),
    'retryIndex': retryIndex,
    'phase': phase.name,
    'attachment': <String, dynamic>{
      'type': attachmentIntent.type.name,
      'profileType': attachmentIntent.profileType,
      'targetId': attachmentIntent.targetId,
      'title': attachmentIntent.title,
      'expectedVersion': attachmentIntent.expectedVersion,
    },
    'completedMediaId': completedMediaId,
    'sourceUrl': sourceUrl,
    'playbackUrl': playbackUrl,
  };

  static PendingProfileUpload? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sessionKey = value['sessionKey']?.toString().trim() ?? '';
    final assetId = value['assetId']?.toString().trim() ?? '';
    final ownerType = value['ownerType']?.toString().trim() ?? '';
    final ownerId = value['ownerId']?.toString().trim() ?? '';
    final mediaKind = value['mediaKind']?.toString().trim() ?? '';
    final deadline = DateTime.tryParse(value['deadline']?.toString() ?? '');
    final retryIndex = int.tryParse(value['retryIndex']?.toString() ?? '0');
    final phase = PendingProfileUploadPhase.values
        .where((item) => item.name == value['phase']?.toString())
        .firstOrNull;
    final attachment = value['attachment'];
    if (sessionKey.isEmpty ||
        assetId.isEmpty ||
        ownerType.isEmpty ||
        ownerId.isEmpty ||
        mediaKind.isEmpty ||
        deadline == null ||
        retryIndex == null ||
        retryIndex < 0 ||
        phase == null ||
        attachment is! Map<String, dynamic>) {
      return null;
    }
    final attachmentType = ProfileUploadAttachmentType.values
        .where((item) => item.name == attachment['type']?.toString())
        .firstOrNull;
    if (attachmentType == null) return null;
    final profileType = attachment['profileType']?.toString();
    final targetId = attachment['targetId']?.toString();
    final title = attachment['title']?.toString();
    final rawExpectedVersion = attachment['expectedVersion'];
    final expectedVersion = rawExpectedVersion == null
        ? null
        : int.tryParse(rawExpectedVersion.toString());
    if (rawExpectedVersion != null &&
        (expectedVersion == null || expectedVersion < 0)) {
      return null;
    }
    final intent = switch (attachmentType) {
      ProfileUploadAttachmentType.none =>
        const ProfileUploadAttachmentIntent.none(),
      ProfileUploadAttachmentType.draft =>
        const ProfileUploadAttachmentIntent.draft(),
      ProfileUploadAttachmentType.gallery =>
        ProfileUploadAttachmentIntent.gallery(profileType: profileType ?? ''),
      ProfileUploadAttachmentType.profilePicture =>
        ProfileUploadAttachmentIntent.profilePicture(
          profileType: profileType ?? '',
          targetId: targetId,
          expectedVersion: expectedVersion,
        ),
      ProfileUploadAttachmentType.track => ProfileUploadAttachmentIntent.track(
        ownerType: profileType ?? '',
        title: title ?? '',
      ),
    };
    return PendingProfileUpload(
      sessionKey: sessionKey,
      assetId: assetId,
      ownerType: ownerType,
      ownerId: ownerId,
      mediaKind: mediaKind,
      deadline: deadline.toUtc(),
      retryIndex: retryIndex,
      phase: phase,
      attachmentIntent: intent,
      completedMediaId: value['completedMediaId']?.toString(),
      sourceUrl: value['sourceUrl']?.toString(),
      playbackUrl: value['playbackUrl']?.toString(),
    );
  }
}

abstract class PendingProfileUploadStore {
  Future<List<PendingProfileUpload>> readAll();

  Future<void> upsert(PendingProfileUpload pending);

  Future<void> remove(String key);
}

class SharedPreferencesPendingProfileUploadStore
    implements PendingProfileUploadStore {
  static const String _storageKey = 'soundconnect.pending_profile_uploads.v1';
  static const String _corruptStorageKey =
      'soundconnect.pending_profile_uploads.v1.corrupt';
  static const int _envelopeVersion = 1;

  final Map<String, PendingProfileUpload> _cache =
      <String, PendingProfileUpload>{};
  final Future<PendingUploadPreferences> Function() _preferencesLoader;
  PendingUploadPreferences? _preferences;
  bool _loaded = false;
  Future<void> _tail = Future<void>.value();

  SharedPreferencesPendingProfileUploadStore({
    Future<PendingUploadPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader =
           preferencesLoader ??
           (() async => SharedPreferencesPendingUploadPreferences(
             await SharedPreferences.getInstance(),
           ));

  @override
  Future<List<PendingProfileUpload>> readAll() {
    return _synchronized(() async {
      await _ensureLoaded();
      return List<PendingProfileUpload>.unmodifiable(_cache.values);
    });
  }

  @override
  Future<void> upsert(PendingProfileUpload pending) {
    return _synchronized(() async {
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
  }

  @override
  Future<void> remove(String key) {
    return _synchronized(() async {
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
  }

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
    final preferences = await _loadPreferences();
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
        // Backwards-compatible read for the original list-only format.
        final List<dynamic> values => values,
        _ => throw const FormatException('Invalid pending upload envelope'),
      };
      final loaded = <String, PendingProfileUpload>{};
      for (final item in items) {
        final normalized = item is Map ? Map<String, dynamic>.from(item) : null;
        final pending = PendingProfileUpload.fromJson(normalized);
        if (pending == null) {
          throw const FormatException('Invalid pending upload item');
        }
        loaded[pending.key] = pending;
      }
      _cache
        ..clear()
        ..addAll(loaded);
      _loaded = true;
    } on FormatException {
      await _quarantineCorruptPayload(preferences, raw);
      _cache.clear();
      _loaded = true;
    } on JsonUnsupportedObjectError {
      await _quarantineCorruptPayload(preferences, raw);
      _cache.clear();
      _loaded = true;
    } on Object catch (error, stackTrace) {
      // jsonDecode throws FormatException for malformed JSON. Any other error
      // is a storage/runtime failure and must stay visible to the caller.
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Pending upload queue could not be loaded',
          error,
        ),
        stackTrace,
      );
    }
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) {
      throw const PendingUploadPersistenceException(
        'Pending upload preferences are unavailable',
      );
    }
    final payload = <String, Object?>{
      'version': _envelopeVersion,
      'items': _cache.values.map((item) => item.toJson()).toList(),
    };
    try {
      final written = await preferences.setString(
        _storageKey,
        jsonEncode(payload),
      );
      if (!written) {
        throw const PendingUploadPersistenceException(
          'Pending upload queue write was rejected',
        );
      }
    } on PendingUploadPersistenceException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Pending upload queue could not be written',
          error,
        ),
        stackTrace,
      );
    }
  }

  Future<PendingUploadPreferences> _loadPreferences() async {
    try {
      return await _preferencesLoader();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Pending upload preferences are unavailable',
          error,
        ),
        stackTrace,
      );
    }
  }

  Future<void> _quarantineCorruptPayload(
    PendingUploadPreferences preferences,
    String raw,
  ) async {
    try {
      await preferences.setString(_corruptStorageKey, raw);
    } catch (_) {
      // Quarantine is best-effort; removing the payload that blocks queue
      // recovery remains mandatory.
    }
    try {
      final removed = await preferences.remove(_storageKey);
      if (!removed) {
        throw const PendingUploadPersistenceException(
          'Corrupt pending upload payload could not be removed',
        );
      }
    } on PendingUploadPersistenceException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PendingUploadPersistenceException(
          'Corrupt pending upload payload could not be removed',
          error,
        ),
        stackTrace,
      );
    }
  }
}

abstract interface class PendingUploadPreferences {
  String? getString(String key);

  Future<bool> setString(String key, String value);

  Future<bool> remove(String key);
}

class SharedPreferencesPendingUploadPreferences
    implements PendingUploadPreferences {
  const SharedPreferencesPendingUploadPreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);
}

class PendingUploadPersistenceException implements Exception {
  const PendingUploadPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'PendingUploadPersistenceException: $message';
}

class MemoryPendingProfileUploadStore implements PendingProfileUploadStore {
  final Map<String, PendingProfileUpload> _items =
      <String, PendingProfileUpload>{};

  MemoryPendingProfileUploadStore([
    Iterable<PendingProfileUpload> seed = const [],
  ]) {
    for (final item in seed) {
      _items[item.key] = item;
    }
  }

  @override
  Future<List<PendingProfileUpload>> readAll() async =>
      List<PendingProfileUpload>.unmodifiable(_items.values);

  @override
  Future<void> remove(String key) async {
    _items.remove(key);
  }

  @override
  Future<void> upsert(PendingProfileUpload pending) async {
    _items[pending.key] = pending;
  }
}
