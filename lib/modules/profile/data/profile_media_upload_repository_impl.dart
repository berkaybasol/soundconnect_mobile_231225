import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/profile_upload_result.dart';
import '../domain/profile_media_upload_repository.dart';
import 'pending_draft_media_cleanup_store.dart';
import 'pending_profile_upload_store.dart';

class ProfileMediaUploadRepositoryImpl implements ProfileMediaUploadRepository {
  static const String _mediaAssetNotReadyCode = '1814';
  static const Duration _defaultCompletionDeadline = Duration(minutes: 6);
  static final List<Duration> _defaultCompletionRetryDelays =
      List<Duration>.unmodifiable(<Duration>[
        const Duration(milliseconds: 250),
        const Duration(milliseconds: 500),
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        ...List<Duration>.filled(60, const Duration(seconds: 5)),
      ]);

  final ApiClient _apiClient;
  final Dio _uploadClient;
  final List<Duration> _completionRetryDelays;
  final Duration _completionDeadline;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _clock;
  final String? Function() _sessionKeyProvider;
  final PendingProfileUploadStore _pendingStore;
  final PendingDraftMediaCleanupStore _pendingDraftCleanupStore;
  final StreamController<ProfileUploadRecoveryEvent> _recoveryEvents =
      StreamController<ProfileUploadRecoveryEvent>.broadcast();
  final Map<String, Future<ProfileUploadedMedia>> _inFlight =
      <String, Future<ProfileUploadedMedia>>{};
  final Set<String> _activeDraftCleanupLeases = <String>{};

  ProfileMediaUploadRepositoryImpl(
    this._apiClient, {
    Dio? uploadClient,
    List<Duration>? completionRetryDelays,
    Duration completionDeadline = _defaultCompletionDeadline,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? clock,
    String? Function()? sessionKeyProvider,
    PendingProfileUploadStore? pendingStore,
    PendingDraftMediaCleanupStore? pendingDraftCleanupStore,
  }) : assert(!completionDeadline.isNegative),
       _uploadClient =
           uploadClient ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(minutes: 10),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _completionRetryDelays = List<Duration>.unmodifiable(
         completionRetryDelays ?? _defaultCompletionRetryDelays,
       ),
       _completionDeadline = completionDeadline,
       _delay = delay ?? _wait,
       _clock = clock ?? DateTime.now,
       _sessionKeyProvider = sessionKeyProvider ?? _localSession,
       _pendingStore = pendingStore ?? MemoryPendingProfileUploadStore(),
       _pendingDraftCleanupStore =
           pendingDraftCleanupStore ?? MemoryPendingDraftMediaCleanupStore();

  @override
  Stream<ProfileUploadRecoveryEvent> get recoveryEvents =>
      _recoveryEvents.stream;

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
  }) async {
    if (source.sizeBytes <= 0) {
      return Result.failure(
        const AppError(
          code: 'profile_upload_empty',
          message: 'Yuklenecek dosya bos olamaz',
        ),
      );
    }
    final intentError = _validateIntent(attachmentIntent);
    if (intentError != null) return Result.failure(intentError);

    final sessionKey = _normalizedSessionKey();
    if (sessionKey == null) {
      return Result.failure(
        const AppError(
          code: 'profile_upload_session_missing',
          message: 'Yukleme icin aktif oturum bulunamadi',
        ),
      );
    }

    final cancelToken = CancelToken();
    cancellation?.attach(cancelToken.cancel);
    try {
      if (cancellation?.isCancelled == true) return _cancelledResult();

      onStageChanged?.call(ProfileUploadStage.initializing);
      final initResult = await _apiClient.post<ProfileUploadInitResult>(
        '/api/v1/user/media/init-upload',
        body: {
          'ownerType': ownerType,
          'ownerId': ownerId,
          'kind': mediaKind,
          'visibility': 'PUBLIC',
          'mimeType': mimeType,
          'sizeBytes': source.sizeBytes,
          'originalFileName': originalFileName,
        },
        decoder: (json) =>
            ProfileUploadInitResult.fromJson(json as Map<String, dynamic>),
      );

      var pending = PendingProfileUpload(
        sessionKey: sessionKey,
        assetId: initResult.assetId,
        ownerType: ownerType,
        ownerId: ownerId,
        mediaKind: mediaKind,
        deadline: _clock().toUtc().add(_completionDeadline),
        retryIndex: 0,
        phase: PendingProfileUploadPhase.uploading,
        attachmentIntent: attachmentIntent,
      );
      // This is the durable commit point. The intent must exist before the
      // first S3 byte is sent so process death and response-loss ambiguity can
      // never orphan a successfully uploaded object.
      await _pendingStore.upsert(pending);
      if (cancellation?.isCancelled == true) {
        // The PUT has definitely not started, so there is no ambiguous remote
        // side effect to recover.
        await _pendingStore.remove(pending.key);
        return _cancelledResult();
      }

      onStageChanged?.call(ProfileUploadStage.uploading);
      final uploadStream = source.openRead().map(
        (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      );
      try {
        await _uploadClient.put<void>(
          initResult.uploadUrl,
          data: uploadStream,
          cancelToken: cancelToken,
          onSendProgress: onProgress,
          options: Options(
            headers: <String, Object>{
              Headers.contentTypeHeader: mimeType,
              Headers.contentLengthHeader: source.sizeBytes,
            },
            contentType: mimeType,
          ),
        );
      } on DioException {
        // A cancelled/failed client response does not prove S3 rejected the
        // object. Keep UPLOADING and reconcile through complete-upload.
        unawaited(_recoverAmbiguousUpload(pending));
        rethrow;
      }

      pending = pending.copyWith(phase: PendingProfileUploadPhase.verifying);
      try {
        await _pendingStore.upsert(pending);
      } catch (_) {
        // The previous durable UPLOADING record remains recoverable.
        unawaited(
          _recoverAmbiguousUpload(
            pending.copyWith(phase: PendingProfileUploadPhase.uploading),
          ),
        );
        rethrow;
      }

      final completed = await _awaitProcessing(
        pending,
        cancellation: cancellation,
        onStageChanged: onStageChanged,
      );
      return Result.success(completed);
    } on _ProfileUploadCancelled {
      return _backgroundProcessingResult();
    } on _ProfileUploadSessionChanged {
      return Result.failure(
        const AppError(
          code: 'profile_upload_session_changed',
          message: 'Oturum degisti; yukleme eski hesap icin bekletiliyor',
        ),
      );
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return _cancelledResult();
      return Result.failure(
        AppError(
          code: 'profile_upload_transport',
          message: error.message ?? 'Medya yuklenemedi',
        ),
      );
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'profile_upload_unknown',
          message: 'Medya yuklenemedi',
        ),
      );
    } finally {
      cancellation?.detach();
    }
  }

  @override
  Future<void> resumePendingUploads() async {
    final sessionKey = _normalizedSessionKey();
    if (sessionKey == null) return;
    final pending = await _pendingStore.readAll();
    final operations = pending
        .where((item) => item.sessionKey == sessionKey)
        .map((item) async {
          try {
            await _ensureProcessing(item);
          } catch (_) {
            // The recovery event and durable record carry the outcome. One
            // failed item must not prevent the rest of the queue from running.
          }
        });
    await Future.wait(operations);
    await _resumePendingDraftCleanup(sessionKey);
  }

  @override
  Future<Result<void>> persistDraftCleanupIntent({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    final normalizedAssetId = assetId.trim();
    final normalizedOwnerType = ownerType.trim().toUpperCase();
    final normalizedOwnerId = ownerId.trim();
    if (normalizedAssetId.isEmpty ||
        normalizedOwnerType.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_draft_cleanup_invalid',
          message: 'Taslak medya bilgisi geçersiz',
        ),
      );
    }
    final sessionKey = _normalizedSessionKey();
    if (sessionKey == null) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_upload_session_missing',
          message: 'Taslak medya için aktif oturum bulunamadı',
        ),
      );
    }
    try {
      await _pendingDraftCleanupStore.upsert(
        PendingDraftMediaCleanup(
          sessionKey: sessionKey,
          assetId: normalizedAssetId,
          ownerType: normalizedOwnerType,
          ownerId: normalizedOwnerId,
          createdAt: _clock().toUtc(),
        ),
      );
      _activeDraftCleanupLeases.add('$sessionKey:$normalizedAssetId');
      return const Result<void>.success(null);
    } catch (_) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_draft_cleanup_persist_failed',
          message: 'Taslak medya güvenli temizleme sırasına alınamadı',
        ),
      );
    }
  }

  @override
  Future<Result<void>> clearDraftCleanupIntents(
    Iterable<String> assetIds,
  ) async {
    final sessionKey = _normalizedSessionKey();
    if (sessionKey == null) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_upload_session_missing',
          message: 'Taslak medya için aktif oturum bulunamadı',
        ),
      );
    }
    final normalizedIds = assetIds
        .map((assetId) => assetId.trim())
        .where((assetId) => assetId.isNotEmpty)
        .toSet();
    try {
      for (final assetId in normalizedIds) {
        final key = '$sessionKey:$assetId';
        await _pendingDraftCleanupStore.remove(key);
        _activeDraftCleanupLeases.remove(key);
      }
      return const Result<void>.success(null);
    } catch (_) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_draft_cleanup_clear_failed',
          message: 'Taslak medya temizleme kaydı güncellenemedi',
        ),
      );
    }
  }

  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {
    final normalizedIds = assetIds
        .map((assetId) => assetId.trim())
        .where((assetId) => assetId.isNotEmpty)
        .toSet();
    _activeDraftCleanupLeases.removeWhere((key) {
      final separator = key.indexOf(':');
      if (separator < 0 || separator == key.length - 1) return false;
      return normalizedIds.contains(key.substring(separator + 1));
    });
  }

  Future<void> _resumePendingDraftCleanup(String sessionKey) async {
    final pendingItems = await _pendingDraftCleanupStore.readAll();
    for (final pending in pendingItems) {
      if (pending.sessionKey != sessionKey) continue;
      if (_activeDraftCleanupLeases.contains(pending.key)) continue;
      final result = await deleteOwnedAsset(
        assetId: pending.assetId,
        ownerType: pending.ownerType,
        ownerId: pending.ownerId,
      );
      final code = result.error?.code.trim() ?? '';
      if (result.isSuccess || code == '1800' || code == '1823') {
        await _pendingDraftCleanupStore.remove(pending.key);
      }
    }
  }

  @override
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async {
    final normalizedAssetId = assetId.trim();
    final normalizedOwnerType = ownerType.trim().toUpperCase();
    final normalizedOwnerId = ownerId.trim();
    if (normalizedAssetId.isEmpty ||
        normalizedOwnerType.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_media_delete_invalid',
          message: 'Silinecek medya bilgisi geçersiz',
        ),
      );
    }

    final sessionKey = _normalizedSessionKey();
    if (sessionKey == null) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_upload_session_missing',
          message: 'Medya işlemi için aktif oturum bulunamadı',
        ),
      );
    }

    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.delete,
        '/api/v1/user/media/$normalizedAssetId',
        query: <String, dynamic>{
          'actingAsType': normalizedOwnerType,
          'actingAsId': normalizedOwnerId,
        },
        requestContext: ApiRequestContext(expectedSessionKey: sessionKey),
        decoder: (_) => null,
      );
      return const Result<void>.success(null);
    } on ApiException catch (error) {
      return Result<void>.failure(error.error);
    } catch (_) {
      return const Result<void>.failure(
        AppError(
          code: 'profile_media_delete_unknown',
          message: 'Medya güvenli biçimde kaldırılamadı',
        ),
      );
    }
  }

  Future<ProfileUploadedMedia> _awaitProcessing(
    PendingProfileUpload pending, {
    ProfileUploadCancellation? cancellation,
    ProfileUploadStageChanged? onStageChanged,
  }) {
    var forwardStages = true;
    final callerResult = Completer<ProfileUploadedMedia>();
    final processing = _ensureProcessing(
      pending,
      onStageChanged: (stage) {
        if (forwardStages) onStageChanged?.call(stage);
      },
    );
    processing
        .then<void>(
          (media) {
            if (!callerResult.isCompleted) callerResult.complete(media);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!callerResult.isCompleted) {
              callerResult.completeError(error, stackTrace);
            }
          },
        )
        .ignore();

    if (cancellation != null) {
      cancellation.whenCancelled.then<void>((_) {
        if (callerResult.isCompleted) return;
        forwardStages = false;
        onStageChanged?.call(ProfileUploadStage.backgroundProcessing);
        _emit(pending, ProfileUploadStage.backgroundProcessing);
        callerResult.completeError(const _ProfileUploadCancelled());
      }).ignore();
    }
    return callerResult.future;
  }

  Future<ProfileUploadedMedia> _ensureProcessing(
    PendingProfileUpload pending, {
    ProfileUploadStageChanged? onStageChanged,
  }) {
    final existing = _inFlight[pending.key];
    if (existing != null) return existing;
    final operation = _processPending(pending, onStageChanged: onStageChanged);
    _inFlight[pending.key] = operation;
    operation.whenComplete(() {
      if (identical(_inFlight[pending.key], operation)) {
        _inFlight.remove(pending.key);
      }
    }).ignore();
    return operation;
  }

  Future<ProfileUploadedMedia> _processPending(
    PendingProfileUpload initial, {
    ProfileUploadStageChanged? onStageChanged,
  }) async {
    var pending = initial;
    _assertActiveSession(pending);
    if (pending.phase == PendingProfileUploadPhase.uploading ||
        pending.phase == PendingProfileUploadPhase.verifying) {
      if (!_clock().toUtc().isBefore(pending.deadline.toUtc())) {
        pending = pending.copyWith(
          deadline: _clock().toUtc().add(_completionDeadline),
          retryIndex: 0,
        );
        await _pendingStore.upsert(pending);
      }
      onStageChanged?.call(ProfileUploadStage.verifying);
      _emit(pending, ProfileUploadStage.verifying);
      while (true) {
        _assertActiveSession(pending);
        try {
          final completed = await _completeOnce(pending);
          // The fenced request was dispatched for this pending upload's
          // session. Even if the foreground account changes while that
          // response is in flight, persist the verified result against the
          // original session before stopping. The session assertion below
          // still prevents any attachment request from crossing accounts.
          pending = pending.copyWith(
            phase: PendingProfileUploadPhase.attaching,
            completedMediaId: completed.uuid.trim().isEmpty
                ? pending.assetId
                : completed.uuid.trim(),
            sourceUrl: completed.sourceUrl,
            playbackUrl: completed.playbackUrl,
          );
          await _pendingStore.upsert(pending);
          break;
        } on ApiException catch (error) {
          if (error.error.code != _mediaAssetNotReadyCode) {
            if (pending.phase == PendingProfileUploadPhase.uploading) {
              // While the S3 response is ambiguous, absence/invalid-state is
              // not proof that the PUT never committed. Retain the intent for
              // a later reconciliation instead of creating an orphan.
              _emit(
                pending,
                ProfileUploadStage.backgroundProcessing,
                error: error.error,
              );
              rethrow;
            }
            if (!_isRecoverableRequestCode(error.error.code)) {
              await _pendingStore.remove(pending.key);
              _emit(pending, ProfileUploadStage.verifying, error: error.error);
            } else {
              _emit(
                pending,
                ProfileUploadStage.backgroundProcessing,
                error: error.error,
              );
            }
            rethrow;
          }
          final retryIndex = pending.retryIndex;
          final deadlineReached = !_clock().toUtc().isBefore(
            pending.deadline.toUtc(),
          );
          if (deadlineReached || retryIndex >= _completionRetryDelays.length) {
            const processing = AppError(
              code: 'profile_upload_processing',
              message: 'Dosya alindi; dogrulama arka planda devam edecek',
            );
            _emit(
              pending,
              ProfileUploadStage.backgroundProcessing,
              error: processing,
            );
            throw ApiException(processing);
          }
          pending = pending.copyWith(retryIndex: retryIndex + 1);
          await _pendingStore.upsert(pending);
          await _delay(_completionRetryDelays[retryIndex]);
        }
      }
    }

    _assertActiveSession(pending);
    onStageChanged?.call(ProfileUploadStage.attaching);
    _emit(pending, ProfileUploadStage.attaching);
    final media = ProfileUploadedMedia(
      uuid: pending.completedMediaId ?? pending.assetId,
      sourceUrl: pending.sourceUrl,
      playbackUrl: pending.playbackUrl,
    );
    try {
      await _attach(pending, media.uuid);
      _assertActiveSession(pending);
    } on ApiException catch (error) {
      if (!_isRecoverableRequestCode(error.error.code)) {
        await _pendingStore.remove(pending.key);
      }
      _emit(
        pending,
        ProfileUploadStage.attaching,
        media: media,
        error: error.error,
      );
      rethrow;
    }
    await _pendingStore.remove(pending.key);
    onStageChanged?.call(ProfileUploadStage.completed);
    _emit(pending, ProfileUploadStage.completed, media: media);
    return media;
  }

  Future<ProfileUploadedMedia> _completeOnce(PendingProfileUpload pending) {
    return _apiClient.request<ProfileUploadedMedia>(
      ApiHttpMethod.post,
      '/api/v1/user/media/complete-upload',
      body: {'assetId': pending.assetId},
      requestContext: _requestContext(pending),
      decoder: (json) =>
          ProfileUploadedMedia.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> _attach(PendingProfileUpload pending, String mediaId) async {
    _assertActiveSession(pending);
    final intent = pending.attachmentIntent;
    switch (intent.type) {
      case ProfileUploadAttachmentType.none:
        return;
      case ProfileUploadAttachmentType.draft:
        await _pendingDraftCleanupStore.upsert(
          PendingDraftMediaCleanup(
            sessionKey: pending.sessionKey,
            assetId: mediaId,
            ownerType: pending.ownerType.trim().toUpperCase(),
            ownerId: pending.ownerId,
            createdAt: _clock().toUtc(),
          ),
        );
        return;
      case ProfileUploadAttachmentType.gallery:
        final profileType = intent.profileType!.trim().toUpperCase();
        if (await _profileMediaAlreadyReferences(
          pending: pending,
          profileType: profileType,
          profileId: pending.ownerId,
          mediaId: mediaId,
        )) {
          return;
        }
        _assertActiveSession(pending);
        await _apiClient.request<Object?>(
          ApiHttpMethod.post,
          '/api/v1/profile-media',
          body: {
            'profileType': profileType,
            'profileId': pending.ownerId,
            'mediaAssetId': mediaId,
            'role': 'GALLERY',
            'orderIndex': null,
          },
          requestContext: _requestContext(pending),
          decoder: (_) => null,
        );
        return;
      case ProfileUploadAttachmentType.profilePicture:
        final profileType = intent.profileType!.trim().toUpperCase();
        final endpoint = switch (profileType) {
          'MUSICIAN' ||
          'MUSICIAN_PROFILE' => '/api/v1/user/musician-profiles/update',
          'BAND' => '/api/v1/user/bands/${pending.ownerId}',
          'VENUE' || 'VENUE_PROFILE' =>
            '/api/v1/user/venue-profiles/me/${intent.targetId}/detail',
          'STUDIO' || 'STUDIO_PROFILE' => '/api/v1/user/studio-profiles/update',
          _ => throw StateError('Unsupported profile picture owner'),
        };
        _assertActiveSession(pending);
        await _apiClient.request<Object?>(
          ApiHttpMethod.put,
          endpoint,
          body: {'profilePicture': mediaId},
          requestContext: _requestContext(pending),
          decoder: (json) => json,
        );
        return;
      case ProfileUploadAttachmentType.track:
        final ownerType = intent.profileType!.trim().toUpperCase();
        if (await _profileMediaAlreadyReferences(
          pending: pending,
          profileType: switch (ownerType) {
            'BAND' => 'BAND',
            'STUDIO' || 'STUDIO_PROFILE' => 'STUDIO',
            _ => 'MUSICIAN',
          },
          profileId: pending.ownerId,
          mediaId: mediaId,
        )) {
          return;
        }
        final endpoint = switch (ownerType) {
          'BAND' => '/api/v1/bands/${pending.ownerId}/tracks',
          'STUDIO' || 'STUDIO_PROFILE' =>
            '/api/v1/studio-profiles/${pending.ownerId}/tracks',
          _ => '/api/v1/musician-profiles/${pending.ownerId}/tracks',
        };
        _assertActiveSession(pending);
        await _apiClient.request<Object?>(
          ApiHttpMethod.post,
          endpoint,
          body: {
            'mediaAssetId': mediaId,
            'title': intent.title!.trim(),
            'durationSeconds': null,
            'bpm': null,
          },
          requestContext: _requestContext(pending),
          decoder: (_) => null,
        );
        return;
    }
  }

  Future<bool> _profileMediaAlreadyReferences({
    required PendingProfileUpload pending,
    required String profileType,
    required String profileId,
    required String mediaId,
  }) async {
    _assertActiveSession(pending);
    final payload = await _apiClient.request<Object?>(
      ApiHttpMethod.get,
      '/api/v1/profiles/$profileType/$profileId/media',
      requestContext: _requestContext(pending),
      decoder: (json) => json,
    );
    _assertActiveSession(pending);
    return _containsMediaReference(payload, mediaId);
  }

  bool _containsMediaReference(Object? value, String mediaId) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if ((key == 'uuid' || key == 'id' || key == 'mediaAssetId') &&
            entry.value?.toString() == mediaId) {
          return true;
        }
        if (_containsMediaReference(entry.value, mediaId)) return true;
      }
    } else if (value is Iterable) {
      for (final item in value) {
        if (_containsMediaReference(item, mediaId)) return true;
      }
    }
    return false;
  }

  AppError? _validateIntent(ProfileUploadAttachmentIntent intent) {
    final profileType = intent.profileType?.trim() ?? '';
    return switch (intent.type) {
      ProfileUploadAttachmentType.none => null,
      ProfileUploadAttachmentType.draft => null,
      ProfileUploadAttachmentType.gallery when profileType.isNotEmpty => null,
      ProfileUploadAttachmentType.profilePicture
          when profileType.isNotEmpty &&
              (!profileType.toUpperCase().startsWith('VENUE') ||
                  (intent.targetId?.trim().isNotEmpty ?? false)) =>
        null,
      ProfileUploadAttachmentType.track
          when profileType.isNotEmpty &&
              (intent.title?.trim().isNotEmpty ?? false) =>
        null,
      _ => const AppError(
        code: 'profile_upload_intent_invalid',
        message: 'Yukleme sonrasi baglama bilgisi gecersiz',
      ),
    };
  }

  bool _isRecoverableRequestCode(String code) {
    final normalized = code.trim().toLowerCase();
    final status = int.tryParse(normalized);
    return normalized == 'network' ||
        normalized == 'api_session_fence' ||
        status == 401 ||
        status == 403 ||
        status == 408 ||
        status == 429 ||
        (status != null && status >= 500 && status <= 599);
  }

  void _assertActiveSession(PendingProfileUpload pending) {
    if (_normalizedSessionKey() != pending.sessionKey) {
      throw const _ProfileUploadSessionChanged();
    }
  }

  ApiRequestContext _requestContext(PendingProfileUpload pending) =>
      ApiRequestContext(expectedSessionKey: pending.sessionKey);

  Future<void> _recoverAmbiguousUpload(PendingProfileUpload pending) async {
    try {
      await _ensureProcessing(pending);
    } catch (_) {
      // The durable UPLOADING record intentionally survives. A later app
      // resume/session restore will reconcile it again.
    }
  }

  void _emit(
    PendingProfileUpload pending,
    ProfileUploadStage stage, {
    ProfileUploadedMedia? media,
    Object? error,
  }) {
    if (_recoveryEvents.isClosed) return;
    _recoveryEvents.add(
      ProfileUploadRecoveryEvent(
        assetId: pending.assetId,
        ownerType: pending.ownerType,
        ownerId: pending.ownerId,
        stage: stage,
        media: media,
        error: error,
      ),
    );
  }

  String? _normalizedSessionKey() {
    final key = _sessionKeyProvider()?.trim() ?? '';
    return key.isEmpty ? null : key;
  }

  Result<ProfileUploadedMedia> _cancelledResult() {
    return Result.failure(
      const AppError(
        code: 'profile_upload_cancelled',
        message: 'Medya yuklemesi iptal edildi',
      ),
    );
  }

  Result<ProfileUploadedMedia> _backgroundProcessingResult() {
    return Result.failure(
      const AppError(
        code: 'profile_upload_processing',
        message: 'Dosya alindi; islem arka planda guvenle devam ediyor',
      ),
    );
  }

  static String _localSession() => 'local';

  static Future<void> _wait(Duration delay) => Future<void>.delayed(delay);
}

class _ProfileUploadCancelled implements Exception {
  const _ProfileUploadCancelled();
}

class _ProfileUploadSessionChanged implements Exception {
  const _ProfileUploadSessionChanged();
}
