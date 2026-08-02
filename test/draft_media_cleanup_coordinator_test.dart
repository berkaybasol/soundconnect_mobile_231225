import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/draft_media_cleanup_coordinator.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_upload_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

void main() {
  group('DraftMediaCleanupCoordinator', () {
    test('never deletes an untracked persisted asset', () async {
      final repository = _CleanupRepository();
      final coordinator = _coordinator(repository);

      final result = await coordinator.discard('persisted-media');

      expect(result.disposition, DraftMediaDiscardDisposition.ignored);
      expect(repository.deletedAssetIds, isEmpty);
    });

    test('committed draft media is removed from compensation scope', () async {
      final repository = _CleanupRepository();
      final coordinator = _coordinator(repository);
      await coordinator.trackUploaded('new-media');
      await coordinator.markCommitted(const <String>['new-media']);

      final report = await coordinator.discardAll();

      expect(report.results, isEmpty);
      expect(repository.deletedAssetIds, isEmpty);
    });

    test(
      'deletes new uploads and explicitly detached persisted media',
      () async {
        final repository = _CleanupRepository();
        final coordinator = _coordinator(repository);
        await coordinator.trackUploaded('new-media');
        await coordinator.trackPotentiallyDetached(const <String>[
          'detached-media',
        ]);

        final report = await coordinator.discardAll();

        expect(
          repository.deletedAssetIds,
          unorderedEquals(const <String>['new-media', 'detached-media']),
        );
        expect(report.hasFailures, isFalse);
        expect(coordinator.pendingAssetIds, isEmpty);
      },
    );

    test(
      'treats not-found and referenced responses as terminal safe states',
      () async {
        final repository = _CleanupRepository(
          responses: <String, Result<void>>{
            'missing': const Result<void>.failure(
              AppError(code: '1800', message: 'missing'),
            ),
            'referenced': const Result<void>.failure(
              AppError(code: '1823', message: 'in use'),
            ),
          },
        );
        final coordinator = _coordinator(repository);
        await coordinator.trackUploaded('missing');
        await coordinator.trackUploaded('referenced');

        final report = await coordinator.discardAll();

        expect(report.hasFailures, isFalse);
        expect(report.hasProtectedReferences, isTrue);
        expect(report.deletedOrAbsentAssetIds, contains('missing'));
        expect(coordinator.pendingAssetIds, isEmpty);
      },
    );

    test('retains transient failures so a later cleanup can retry', () async {
      var shouldFail = true;
      final repository = _CleanupRepository(
        callback: (assetId) {
          if (shouldFail) {
            return const Result<void>.failure(
              AppError(code: 'network', message: 'offline'),
            );
          }
          return const Result<void>.success(null);
        },
      );
      final coordinator = _coordinator(repository);
      await coordinator.trackUploaded('new-media');

      final first = await coordinator.discardAll();
      shouldFail = false;
      final second = await coordinator.discardAll();

      expect(first.hasFailures, isTrue);
      expect(second.hasFailures, isFalse);
      expect(repository.deletedAssetIds, <String>['new-media', 'new-media']);
      expect(coordinator.pendingAssetIds, isEmpty);
    });

    test('coalesces concurrent deletion requests for the same asset', () async {
      final completion = Completer<Result<void>>();
      final repository = _CleanupRepository(callback: (_) => completion.future);
      final coordinator = _coordinator(repository);
      await coordinator.trackUploaded('new-media');

      final first = coordinator.discard('new-media');
      final second = coordinator.discard('new-media');
      completion.complete(const Result<void>.success(null));

      expect(identical(first, second), isTrue);
      await Future.wait(<Future<DraftMediaDiscardResult>>[first, second]);
      expect(repository.deletedAssetIds, <String>['new-media']);
    });
  });

  group('studioMutationOutcomeMayBeAmbiguous', () {
    test(
      'separates transport ambiguity from deterministic business errors',
      () {
        expect(
          studioMutationOutcomeMayBeAmbiguous(
            const AppError(code: 'network', message: 'offline'),
          ),
          isTrue,
        );
        expect(
          studioMutationOutcomeMayBeAmbiguous(
            const AppError(
              code: 'studio_equipment_create_unknown',
              message: 'x',
            ),
          ),
          isTrue,
        );
        expect(
          studioMutationOutcomeMayBeAmbiguous(
            const AppError(code: '9804', message: 'stale'),
          ),
          isFalse,
        );
      },
    );
  });
}

DraftMediaCleanupCoordinator _coordinator(
  ProfileMediaUploadRepository repository,
) => DraftMediaCleanupCoordinator(
  repository: repository,
  ownerType: 'STUDIO_PROFILE',
  ownerId: 'studio-1',
);

class _CleanupRepository implements ProfileMediaUploadRepository {
  _CleanupRepository({
    this.responses = const <String, Result<void>>{},
    this.callback,
  });

  final Map<String, Result<void>> responses;
  final FutureOr<Result<void>> Function(String assetId)? callback;
  final List<String> deletedAssetIds = <String>[];
  final Set<String> persistedIntentIds = <String>{};

  @override
  Stream<ProfileUploadRecoveryEvent> get recoveryEvents => const Stream.empty();

  @override
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    expect(ownerType, 'STUDIO_PROFILE');
    expect(ownerId, 'studio-1');
    deletedAssetIds.add(assetId);
    final dynamic response =
        callback?.call(assetId) ??
        responses[assetId] ??
        const Result<void>.success(null);
    return response is Future<Result<void>>
        ? await response
        : response as Result<void>;
  }

  @override
  Future<Result<void>> persistDraftCleanupIntent({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    expect(ownerType, 'STUDIO_PROFILE');
    expect(ownerId, 'studio-1');
    persistedIntentIds.add(assetId);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> clearDraftCleanupIntents(
    Iterable<String> assetIds,
  ) async {
    persistedIntentIds.removeAll(assetIds);
    return const Result<void>.success(null);
  }

  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}

  @override
  Future<void> resumePendingUploads() async {}

  @override
  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required ProfileUploadSource source,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
    ProfileUploadAttachmentIntent attachmentIntent =
        const ProfileUploadAttachmentIntent.none(),
    ProfileUploadProgress? onProgress,
    ProfileUploadStageChanged? onStageChanged,
    ProfileUploadCancellation? cancellation,
  }) => throw UnimplementedError();
}
