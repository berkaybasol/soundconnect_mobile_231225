part of 'profile_upload_repository_test.dart';

void _registerProfileMediaUploadRepositoryImpl2() {
  test(
    'Studio profile picture recovery uses the Studio update contract',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'studio-photo',
          ownerType: 'STUDIO_PROFILE',
          ownerId: 'studio-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
            profileType: 'STUDIO',
          ),
          completedMediaId: 'studio-photo',
        ),
      ]);
      final api = RecordingApiClient((request) {
        expect(request.path, '/api/v1/user/studio-profiles/update');
        expect(request.body, <String, dynamic>{
          'profilePicture': 'studio-photo',
        });
        return <String, dynamic>{};
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await repository.resumePendingUploads();

      expect(api.requests, hasLength(1));
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'Listener profile picture recovery uses dedicated PATCH contract',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'listener-photo',
          ownerType: 'LISTENER_PROFILE',
          ownerId: 'listener-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
            profileType: 'LISTENER_PROFILE',
            expectedVersion: 6,
          ),
          completedMediaId: 'listener-photo',
        ),
      ]);
      final api = RecordingApiClient((request) {
        expect(request.method, RecordedHttpMethod.patch);
        expect(request.path, '/api/v1/user/listener-profiles/me/avatar');
        expect(request.body, <String, dynamic>{
          'profilePictureMediaId': 'listener-photo',
          'expectedVersion': 6,
        });
        return <String, dynamic>{};
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await repository.resumePendingUploads();

      expect(api.requests, hasLength(1));
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'stale listener avatar replay is rejected and deletes verified asset',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'rejected-listener-photo',
          ownerType: 'LISTENER_PROFILE',
          ownerId: 'listener-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
            profileType: 'LISTENER_PROFILE',
            expectedVersion: 8,
          ),
          completedMediaId: 'rejected-listener-photo',
        ),
      ]);
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/listener-profiles/me/avatar') {
          expect(request.body, <String, dynamic>{
            'profilePictureMediaId': 'rejected-listener-photo',
            'expectedVersion': 8,
          });
          throw ApiException(
            const AppError(code: '1304', message: 'stale version'),
          );
        }
        if (request.path == '/api/v1/user/media/rejected-listener-photo') {
          expect(request.method, RecordedHttpMethod.delete);
          expect(request.query, <String, dynamic>{
            'actingAsType': 'LISTENER_PROFILE',
            'actingAsId': 'listener-1',
          });
          return null;
        }
        throw StateError('Unexpected path: ${request.path}');
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await repository.resumePendingUploads();

      expect(
        api.requests.map((request) => request.method),
        <RecordedHttpMethod>[
          RecordedHttpMethod.patch,
          RecordedHttpMethod.delete,
        ],
      );
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'listener avatar cleanup keeps durable intent until deletion succeeds',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'listener-photo-to-retry',
          ownerType: 'LISTENER_PROFILE',
          ownerId: 'listener-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
            profileType: 'LISTENER_PROFILE',
            expectedVersion: 9,
          ),
          completedMediaId: 'listener-photo-to-retry',
        ),
      ]);
      var deletionFails = true;
      var deletionAttempts = 0;
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/listener-profiles/me/avatar') {
          throw ApiException(
            const AppError(code: '1302', message: 'invalid avatar'),
          );
        }
        if (request.path == '/api/v1/user/media/listener-photo-to-retry') {
          deletionAttempts += 1;
          if (deletionFails) {
            throw ApiException(
              const AppError(code: 'network', message: 'offline'),
            );
          }
          return null;
        }
        throw StateError('Unexpected path: ${request.path}');
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await repository.resumePendingUploads();

      expect(deletionAttempts, 1);
      expect(await store.readAll(), hasLength(1));

      deletionFails = false;
      await repository.resumePendingUploads();

      expect(deletionAttempts, 2);
      expect(await store.readAll(), isEmpty);
    },
  );

  test('rejects a new listener avatar upload without a CAS version', () async {
    final api = RecordingApiClient(
      (_) => throw StateError('request must not be dispatched'),
    );
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      sessionKeyProvider: () => 'account-1',
    );

    final result = await repository.uploadAsset(
      source: ProfileUploadSource.bytes(<int>[1, 2, 3]),
      ownerType: 'LISTENER_PROFILE',
      ownerId: 'listener-1',
      mediaKind: 'IMAGE',
      mimeType: 'image/jpeg',
      originalFileName: 'avatar.jpg',
      attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
        profileType: 'LISTENER_PROFILE',
      ),
    );

    expect(result.error?.code, 'profile_upload_intent_invalid');
    expect(api.requests, isEmpty);
  });

  test(
    'retires a legacy listener avatar intent without issuing stale PATCH',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'legacy-listener-photo',
          ownerType: 'LISTENER_PROFILE',
          ownerId: 'listener-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
            profileType: 'LISTENER_PROFILE',
          ),
          completedMediaId: 'legacy-listener-photo',
        ),
      ]);
      final api = RecordingApiClient((request) {
        expect(request.method, RecordedHttpMethod.delete);
        expect(request.path, '/api/v1/user/media/legacy-listener-photo');
        return null;
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await repository.resumePendingUploads();

      expect(api.requests, hasLength(1));
      expect(await store.readAll(), isEmpty);
    },
  );

  test('Studio audio recovery checks and attaches to Studio tracks', () async {
    final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
      PendingProfileUpload(
        sessionKey: 'account-1',
        assetId: 'studio-audio',
        ownerType: 'STUDIO_PROFILE',
        ownerId: 'studio-1',
        mediaKind: 'AUDIO',
        deadline: DateTime.utc(2030),
        retryIndex: 0,
        phase: PendingProfileUploadPhase.attaching,
        attachmentIntent: const ProfileUploadAttachmentIntent.track(
          ownerType: 'STUDIO_PROFILE',
          title: 'Studio take',
        ),
        completedMediaId: 'studio-audio',
      ),
    ]);
    final api = RecordingApiClient((request) {
      if (request.path == '/api/v1/profiles/STUDIO/studio-1/media') {
        return <String, dynamic>{'videos': <Object?>[], 'audios': <Object?>[]};
      }
      expect(request.path, '/api/v1/studio-profiles/studio-1/tracks');
      expect(request.body, <String, dynamic>{
        'mediaAssetId': 'studio-audio',
        'title': 'Studio take',
        'durationSeconds': null,
        'bpm': null,
      });
      return null;
    });
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      pendingStore: store,
      sessionKeyProvider: () => 'account-1',
    );

    await repository.resumePendingUploads();

    expect(api.requests, hasLength(2));
    expect(await store.readAll(), isEmpty);
  });

  test(
    'pauses at the foreground budget, retains intent, and resumes later',
    () async {
      const notReady = AppError(
        code: '1814',
        message: 'Media asset not ready.',
      );
      var completionAttempts = 0;
      final observedDelays = <Duration>[];
      final store = MemoryPendingProfileUploadStore();
      final firstApi = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-1',
            'uploadUrl': 'https://upload.example.test/assets/asset-1',
          };
        }
        completionAttempts++;
        throw ApiException(notReady);
      });
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = ProfileMediaUploadRepositoryImpl(
        firstApi,
        uploadClient: dio,
        pendingStore: store,
        completionRetryDelays: const <Duration>[
          Duration(milliseconds: 250),
          Duration(milliseconds: 500),
        ],
        delay: (delay) async => observedDelays.add(delay),
      );

      final result = await repository.uploadAsset(
        source: ProfileUploadSource.bytes(<int>[1]),
        ownerType: 'MUSICIAN',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'avatar.jpg',
      );

      expect(result.error?.code, 'profile_upload_processing');
      expect(completionAttempts, 3);
      expect(observedDelays, const <Duration>[
        Duration(milliseconds: 250),
        Duration(milliseconds: 500),
      ]);
      expect(await store.readAll(), hasLength(1));

      final resumedApi = RecordingApiClient((request) {
        expect(request.path, '/api/v1/user/media/complete-upload');
        return <String, dynamic>{
          'uuid': 'asset-1',
          'sourceUrl': 'https://cdn.example.test/asset-1.jpg',
        };
      });
      final resumedRepository = ProfileMediaUploadRepositoryImpl(
        resumedApi,
        pendingStore: store,
      );

      await resumedRepository.resumePendingUploads();

      expect(await store.readAll(), isEmpty);
      expect(resumedApi.requests, hasLength(1));
    },
  );

  test('does not retry any completion error other than code 1814', () async {
    const invalidState = AppError(
      code: '1817',
      message: 'Media asset state invalid.',
    );
    var completionAttempts = 0;
    final observedDelays = <Duration>[];
    final store = MemoryPendingProfileUploadStore();
    final api = RecordingApiClient((request) {
      if (request.path == '/api/v1/user/media/init-upload') {
        return <String, dynamic>{
          'assetId': 'asset-1',
          'uploadUrl': 'https://upload.example.test/assets/asset-1',
        };
      }
      completionAttempts++;
      throw ApiException(invalidState);
    });
    final adapter = _UploadAdapter(statusCode: 200);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      uploadClient: dio,
      pendingStore: store,
      completionRetryDelays: const <Duration>[Duration(milliseconds: 1)],
      delay: (delay) async => observedDelays.add(delay),
    );

    final result = await repository.uploadAsset(
      source: ProfileUploadSource.bytes(<int>[1]),
      ownerType: 'MUSICIAN',
      ownerId: 'owner-1',
      mediaKind: 'IMAGE',
      mimeType: 'image/jpeg',
      originalFileName: 'avatar.jpg',
    );

    expect(result.error, same(invalidState));
    expect(completionAttempts, 1);
    expect(observedDelays, isEmpty);
    expect(await store.readAll(), isEmpty);
  });

  test(
    'retains non-ready errors while a persisted PUT outcome is ambiguous',
    () async {
      const absent = AppError(
        code: '1817',
        message: 'Object is not visible yet',
      );
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'asset-ambiguous',
          ownerType: 'MUSICIAN_PROFILE',
          ownerId: 'musician-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.uploading,
          attachmentIntent: const ProfileUploadAttachmentIntent.none(),
        ),
      ]);
      final api = RecordingApiClient((_) => throw ApiException(absent));
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await repository.resumePendingUploads();

      expect(api.requests, hasLength(1));
      final retained = await store.readAll();
      expect(retained, hasLength(1));
      expect(retained.single.phase, PendingProfileUploadPhase.uploading);
    },
  );

  test(
    'cancel after PUT detaches UI while durable completion keeps running',
    () async {
      final completionStarted = Completer<void>();
      final allowCompletion = Completer<Object?>();
      final store = MemoryPendingProfileUploadStore();
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-detached',
            'uploadUrl': 'https://upload.example.test/assets/asset-detached',
          };
        }
        if (!completionStarted.isCompleted) completionStarted.complete();
        return allowCompletion.future;
      });
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final cancellation = ProfileUploadCancellation();
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        uploadClient: dio,
        pendingStore: store,
      );
      final recovered = repository.recoveryEvents.firstWhere(
        (event) => event.isSuccess,
      );

      final resultFuture = repository.uploadAsset(
        source: ProfileUploadSource.bytes(<int>[1, 2, 3]),
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'detached.jpg',
        cancellation: cancellation,
      );
      await completionStarted.future.timeout(const Duration(seconds: 2));

      cancellation.cancel('leave-screen');
      final detached = await resultFuture.timeout(const Duration(seconds: 2));

      expect(detached.error?.code, 'profile_upload_processing');
      expect(await store.readAll(), hasLength(1));

      allowCompletion.complete(<String, dynamic>{
        'uuid': 'asset-detached',
        'sourceUrl': 'https://cdn.example.test/detached.jpg',
      });
      await recovered.timeout(const Duration(seconds: 2));
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'completion transport failure is retained and retried only on resume',
    () async {
      const offline = AppError(code: 'network', message: 'Offline');
      final store = MemoryPendingProfileUploadStore();
      var firstCompletionCalls = 0;
      final firstApi = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-offline',
            'uploadUrl': 'https://upload.example.test/assets/asset-offline',
          };
        }
        firstCompletionCalls++;
        throw ApiException(offline);
      });
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = ProfileMediaUploadRepositoryImpl(
        firstApi,
        uploadClient: dio,
        pendingStore: store,
      );

      final offlineResult = await repository.uploadAsset(
        source: ProfileUploadSource.bytes(<int>[1]),
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'offline.jpg',
      );

      expect(offlineResult.error, same(offline));
      expect(firstCompletionCalls, 1);
      expect(await store.readAll(), hasLength(1));

      final resumedApi = RecordingApiClient((request) {
        return <String, dynamic>{
          'uuid': 'asset-offline',
          'sourceUrl': 'https://cdn.example.test/offline.jpg',
        };
      });
      await ProfileMediaUploadRepositoryImpl(
        resumedApi,
        pendingStore: store,
      ).resumePendingUploads();

      expect(resumedApi.requests, hasLength(1));
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'A to B session switch fences attach and A can resume it later',
    () async {
      var activeSession = 'account-A';
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-A',
          assetId: 'asset-A',
          ownerType: 'VENUE_PROFILE',
          ownerId: 'venue-A',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.verifying,
          attachmentIntent: const ProfileUploadAttachmentIntent.gallery(
            profileType: 'VENUE',
          ),
        ),
      ]);
      final requests = <String>[];
      final events = <ProfileUploadRecoveryEvent>[];
      final api = RecordingApiClient((request) {
        requests.add('$activeSession:${request.path}');
        if (request.path == '/api/v1/user/media/complete-upload') {
          activeSession = 'account-B';
          return <String, dynamic>{
            'uuid': 'asset-A',
            'sourceUrl': 'https://cdn.example.test/A.jpg',
          };
        }
        if (request.path == '/api/v1/profiles/VENUE/venue-A/media') {
          return <String, dynamic>{
            'videos': <Object?>[],
            'audios': <Object?>[],
          };
        }
        if (request.path == '/api/v1/profile-media') return null;
        throw StateError('Unexpected path: ${request.path}');
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => activeSession,
      );
      final subscription = repository.recoveryEvents.listen(events.add);
      addTearDown(subscription.cancel);

      await repository.resumePendingUploads();

      expect(requests, <String>[
        'account-A:/api/v1/user/media/complete-upload',
      ]);
      expect(
        events.where((event) => event.stage == ProfileUploadStage.attaching),
        isEmpty,
      );
      final retained = await store.readAll();
      expect(retained, hasLength(1));
      expect(retained.single.phase, PendingProfileUploadPhase.attaching);

      activeSession = 'account-A';
      await repository.resumePendingUploads();

      expect(
        requests,
        containsAllInOrder(<String>[
          'account-A:/api/v1/profiles/VENUE/venue-A/media',
          'account-A:/api/v1/profile-media',
        ]),
      );
      expect(
        api.requests.every(
          (request) =>
              request.requestContext?.expectedSessionKey == 'account-A',
        ),
        isTrue,
      );
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'cancels active PUT but retains and reconciles its ambiguous intent',
    () async {
      final completionAttempted = Completer<void>();
      final store = MemoryPendingProfileUploadStore();
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-1',
            'uploadUrl': 'https://upload.example.test/assets/asset-1',
          };
        }
        if (!completionAttempted.isCompleted) completionAttempted.complete();
        throw ApiException(const AppError(code: '1814', message: 'Not ready'));
      });
      final adapter = _CancellableUploadAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final cancellation = ProfileUploadCancellation();
      final sourceCancelled = Completer<void>();
      late final StreamController<List<int>> sourceController;
      sourceController = StreamController<List<int>>(
        onListen: () => sourceController.add(<int>[1, 2]),
        onCancel: () {
          if (!sourceCancelled.isCompleted) sourceCancelled.complete();
        },
      );
      addTearDown(sourceController.close);
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        uploadClient: dio,
        pendingStore: store,
        completionRetryDelays: const <Duration>[],
      );

      final resultFuture = repository.uploadAsset(
        source: ProfileUploadSource(
          sizeBytes: 4,
          openRead: () => sourceController.stream,
        ),
        ownerType: 'MUSICIAN',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'avatar.jpg',
        cancellation: cancellation,
      );
      await adapter.started.future.timeout(const Duration(seconds: 2));
      final beforeCancel = await store.readAll();
      expect(beforeCancel, hasLength(1));
      expect(beforeCancel.single.phase, PendingProfileUploadPhase.uploading);

      cancellation.cancel('user-request');
      final result = await resultFuture.timeout(const Duration(seconds: 2));
      await completionAttempted.future.timeout(const Duration(seconds: 2));

      expect(result.error?.code, 'profile_upload_cancelled');
      expect(adapter.cancelFutureObserved, isTrue);
      await expectLater(sourceCancelled.future, completes);
      expect(api.requests, hasLength(2));
      expect(api.requests.first.path, '/api/v1/user/media/init-upload');
      expect(api.requests.last.path, '/api/v1/user/media/complete-upload');
      expect(
        (await store.readAll()).single.phase,
        PendingProfileUploadPhase.uploading,
      );
    },
  );
}
