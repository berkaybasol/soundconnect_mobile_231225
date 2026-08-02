import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import 'profile_media_upload_repository.dart';

enum DraftMediaDiscardDisposition {
  deleted,
  alreadyAbsent,
  protectedByReference,
  failed,
  ignored,
}

class DraftMediaDiscardResult {
  const DraftMediaDiscardResult({
    required this.assetId,
    required this.disposition,
    this.error,
  });

  final String assetId;
  final DraftMediaDiscardDisposition disposition;
  final AppError? error;

  bool get isSafeToForget => switch (disposition) {
    DraftMediaDiscardDisposition.deleted ||
    DraftMediaDiscardDisposition.alreadyAbsent ||
    DraftMediaDiscardDisposition.protectedByReference ||
    DraftMediaDiscardDisposition.ignored => true,
    DraftMediaDiscardDisposition.failed => false,
  };
}

class DraftMediaCleanupReport {
  const DraftMediaCleanupReport(this.results);

  final List<DraftMediaDiscardResult> results;

  bool get hasFailures => results.any(
    (result) => result.disposition == DraftMediaDiscardDisposition.failed,
  );

  bool get hasProtectedReferences => results.any(
    (result) =>
        result.disposition == DraftMediaDiscardDisposition.protectedByReference,
  );

  Set<String> get safelyForgottenAssetIds => Set<String>.unmodifiable(
    results
        .where((result) => result.isSafeToForget)
        .map((result) => result.assetId),
  );

  Set<String> get deletedOrAbsentAssetIds => Set<String>.unmodifiable(
    results
        .where(
          (result) =>
              result.disposition == DraftMediaDiscardDisposition.deleted ||
              result.disposition == DraftMediaDiscardDisposition.alreadyAbsent,
        )
        .map((result) => result.assetId),
  );
}

/// Owns the lifecycle of media uploaded by one draft form session.
///
/// Persisted assets are never implicitly tracked. A caller may schedule them
/// only after a successful entity mutation confirms that their reference was
/// detached. The backend reference guard remains the final safety boundary.
class DraftMediaCleanupCoordinator {
  DraftMediaCleanupCoordinator({
    required ProfileMediaUploadRepository repository,
    required String ownerType,
    required String ownerId,
  }) : _repository = repository,
       _ownerType = ownerType.trim().toUpperCase(),
       _ownerId = ownerId.trim() {
    if (_ownerType.isEmpty || _ownerId.isEmpty) {
      throw ArgumentError('Draft media owner must be provided.');
    }
  }

  static const String mediaNotFoundCode = '1800';
  static const String mediaInUseCode = '1823';

  final ProfileMediaUploadRepository _repository;
  final String _ownerType;
  final String _ownerId;
  final Set<String> _pendingAssetIds = <String>{};
  final Map<String, Future<DraftMediaDiscardResult>> _inFlight =
      <String, Future<DraftMediaDiscardResult>>{};

  Set<String> get pendingAssetIds => Set<String>.unmodifiable(_pendingAssetIds);

  bool isTracked(String assetId) => _pendingAssetIds.contains(assetId.trim());

  Future<Result<void>> trackUploaded(String assetId) async {
    final normalized = assetId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(assetId, 'assetId', 'must not be empty');
    }
    final persisted = await _repository.persistDraftCleanupIntent(
      assetId: normalized,
      ownerType: _ownerType,
      ownerId: _ownerId,
    );
    _pendingAssetIds.add(normalized);
    if (!persisted.isSuccess) {
      // Fail closed: an asset that could not enter the durable queue must not
      // be handed to a form as if crash recovery were guaranteed.
      await discard(normalized);
    }
    return persisted;
  }

  /// Durably queues assets that a pending mutation may detach.
  ///
  /// This intentionally happens before dispatch. If the app dies during an
  /// ambiguous response, the backend reference guard decides whether the old
  /// asset stayed referenced (keep) or was detached (delete).
  Future<Result<void>> trackPotentiallyDetached(
    Iterable<String> assetIds,
  ) async {
    AppError? firstError;
    for (final assetId in assetIds) {
      final normalized = assetId.trim();
      if (normalized.isEmpty) continue;
      final persisted = await _repository.persistDraftCleanupIntent(
        assetId: normalized,
        ownerType: _ownerType,
        ownerId: _ownerId,
      );
      _pendingAssetIds.add(normalized);
      firstError ??= persisted.error;
    }
    return firstError == null
        ? const Result<void>.success(null)
        : Result<void>.failure(firstError);
  }

  Future<Result<void>> markCommitted(Iterable<String> assetIds) async {
    final normalizedIds = assetIds
        .map((assetId) => assetId.trim())
        .where((assetId) => assetId.isNotEmpty)
        .toSet();
    _pendingAssetIds.removeAll(normalizedIds);
    final cleared = await _repository.clearDraftCleanupIntents(normalizedIds);
    if (!cleared.isSuccess) {
      _repository.releaseDraftCleanupLeases(normalizedIds);
    }
    return cleared;
  }

  Future<DraftMediaDiscardResult> discard(String assetId) {
    final normalized = assetId.trim();
    if (normalized.isEmpty || !_pendingAssetIds.contains(normalized)) {
      return Future<DraftMediaDiscardResult>.value(
        DraftMediaDiscardResult(
          assetId: normalized,
          disposition: DraftMediaDiscardDisposition.ignored,
        ),
      );
    }

    final active = _inFlight[normalized];
    if (active != null) return active;
    final operation = _discardTracked(normalized);
    _inFlight[normalized] = operation;
    operation.whenComplete(() {
      if (identical(_inFlight[normalized], operation)) {
        _inFlight.remove(normalized);
      }
    }).ignore();
    return operation;
  }

  Future<DraftMediaCleanupReport> discardAll() async {
    final snapshot = List<String>.of(_pendingAssetIds);
    if (snapshot.isEmpty) return const DraftMediaCleanupReport([]);
    final results = await Future.wait(snapshot.map(discard));
    return DraftMediaCleanupReport(List.unmodifiable(results));
  }

  Future<DraftMediaCleanupReport> close() async {
    final report = await discardAll();
    _repository.releaseDraftCleanupLeases(_pendingAssetIds);
    return report;
  }

  Future<DraftMediaDiscardResult> _discardTracked(String assetId) async {
    final result = await _repository.deleteOwnedAsset(
      assetId: assetId,
      ownerType: _ownerType,
      ownerId: _ownerId,
    );
    if (result.isSuccess) {
      _pendingAssetIds.remove(assetId);
      final cleared = await _repository.clearDraftCleanupIntents(<String>[
        assetId,
      ]);
      if (!cleared.isSuccess) {
        _repository.releaseDraftCleanupLeases(<String>[assetId]);
      }
      return DraftMediaDiscardResult(
        assetId: assetId,
        disposition: DraftMediaDiscardDisposition.deleted,
      );
    }

    final code = result.error?.code.trim() ?? '';
    if (code == mediaNotFoundCode || code == mediaInUseCode) {
      _pendingAssetIds.remove(assetId);
      final cleared = await _repository.clearDraftCleanupIntents(<String>[
        assetId,
      ]);
      if (!cleared.isSuccess) {
        _repository.releaseDraftCleanupLeases(<String>[assetId]);
      }
      return DraftMediaDiscardResult(
        assetId: assetId,
        disposition: code == mediaNotFoundCode
            ? DraftMediaDiscardDisposition.alreadyAbsent
            : DraftMediaDiscardDisposition.protectedByReference,
        error: result.error,
      );
    }
    return DraftMediaDiscardResult(
      assetId: assetId,
      disposition: DraftMediaDiscardDisposition.failed,
      error: result.error,
    );
  }
}

bool studioMutationOutcomeMayBeAmbiguous(AppError? error) {
  if (error == null) return true;
  final code = error.code.trim().toLowerCase();
  final status = int.tryParse(code);
  if (status != null && code.length == 3) {
    return status == 408 || status == 429 || status >= 500;
  }
  // SoundConnect domain error codes are numeric but are not HTTP statuses
  // (for example 9804 is an optimistic-concurrency conflict). Treat them as
  // deterministic business responses so an uploaded draft can be compensated.
  if (status != null) return false;
  return code.contains('network') ||
      code.contains('timeout') ||
      code.contains('transport') ||
      code.contains('unknown') ||
      code.contains('invalid_response') ||
      code == 'api_session_fence';
}
