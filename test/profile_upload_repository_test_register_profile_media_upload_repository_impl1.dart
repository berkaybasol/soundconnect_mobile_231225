part of 'profile_upload_repository_test.dart';

void _registerProfileMediaUploadRepositoryImpl1() {
  test(
    'private init cannot adopt same-account relogin token while token storage is pending',
    () async {
      String jwt(String nonce) {
        String encode(Object data) =>
            base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
        return '${encode({'alg': 'none'})}.${encode({'sub': 'account-A', 'jti': nonce, 'exp': 4102444800})}.signature';
      }

      final oldToken = jwt('old');
      final newToken = jwt('new');
      final sessions = AudienceTestSessions(
        audienceSession(user: 'account-A', token: oldToken),
      );
      addTearDown(sessions.dispose);
      final tokens = _InitBlockedTokens();
      final apiAdapter = _UploadAdapter(statusCode: 200);
      final uploadAdapter = _UploadAdapter(statusCode: 200);
      final apiDio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
        ..httpClientAdapter = apiAdapter;
      final uploadDio = Dio()..httpClientAdapter = uploadAdapter;
      addTearDown(() {
        apiDio.close(force: true);
        uploadDio.close(force: true);
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        DioApiClient(dio: apiDio, tokenStore: tokens, sessionManager: sessions),
        uploadClient: uploadDio,
        sessionKeyProvider: () => sessions.session.userId,
        tokenProvider: () => sessions.session.token,
      );
      final pending = repository.uploadAsset(
        source: ProfileUploadSource.bytes([1, 2, 3]),
        ownerType: 'PROMOTION',
        ownerId: 'draft-id',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'poster.jpg',
        visibility: 'PRIVATE',
        attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
      );
      await tokens.started.future;
      sessions.replace(const AuthSession.guest());
      sessions.replace(audienceSession(user: 'account-A', token: newToken));
      tokens.release.complete(newToken);
      expect((await pending).isSuccess, isFalse);
      expect(apiAdapter.requests, isEmpty);
      expect(uploadAdapter.requests, isEmpty);
    },
  );

  test(
    'private draft upload init cannot adopt another account after token await',
    () async {
      String jwt(String user) {
        String encode(Object data) =>
            base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
        return '${encode({'alg': 'none'})}.${encode({'sub': user, 'exp': 4102444800})}.signature';
      }

      final sessions = AudienceTestSessions(
        audienceSession(user: 'account-A', token: jwt('account-A')),
      );
      addTearDown(sessions.dispose);
      final tokens = _InitBlockedTokens();
      final apiAdapter = _UploadAdapter(statusCode: 200);
      final uploadAdapter = _UploadAdapter(statusCode: 200);
      final apiDio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
        ..httpClientAdapter = apiAdapter;
      final uploadDio = Dio()..httpClientAdapter = uploadAdapter;
      addTearDown(() {
        apiDio.close(force: true);
        uploadDio.close(force: true);
      });
      final repository = ProfileMediaUploadRepositoryImpl(
        DioApiClient(dio: apiDio, tokenStore: tokens, sessionManager: sessions),
        uploadClient: uploadDio,
        sessionKeyProvider: () => sessions.session.userId,
      );
      final pending = repository.uploadAsset(
        source: ProfileUploadSource.bytes([1, 2, 3]),
        ownerType: 'PROMOTION',
        ownerId: 'draft-id',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'poster.jpg',
        visibility: 'PRIVATE',
        attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
      );
      await tokens.started.future;
      sessions.replace(
        audienceSession(user: 'account-B', token: jwt('account-B')),
      );
      tokens.release.complete(jwt('account-B'));
      expect((await pending).isSuccess, isFalse);
      expect(apiAdapter.requests, isEmpty);
      expect(uploadAdapter.requests, isEmpty);
    },
  );

  for (final visibility in ['PUBLIC', 'PRIVATE']) {
    test(
      'uses existing upload/recovery pipeline for $visibility media',
      () async {
        final api = RecordingApiClient((request) {
          if (request.path.endsWith('/init-upload')) {
            return {
              'assetId': 'announcement-media',
              'uploadUrl': 'https://upload.example.test/announcement',
            };
          }
          if (request.path.endsWith('/complete-upload')) {
            return {
              'uuid': 'announcement-media',
              'sourceUrl': null,
              'playbackUrl': null,
            };
          }
          throw StateError('Unexpected request ${request.path}');
        });
        final adapter = _UploadAdapter(statusCode: 200);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final repository = ProfileMediaUploadRepositoryImpl(
          api,
          uploadClient: dio,
          sessionKeyProvider: () => 'admin',
          tokenProvider: () => 'admin-token',
        );
        final result = await repository.uploadAsset(
          source: ProfileUploadSource.bytes([1, 2, 3]),
          ownerType: 'PROMOTION',
          ownerId: 'draft-id',
          mediaKind: 'IMAGE',
          mimeType: 'image/jpeg',
          originalFileName: 'poster.jpg',
          visibility: visibility,
          attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.sourceUrl, isNull);
        expect((api.requests.first.body as Map)['visibility'], visibility);
        expect(api.requests.first.requestContext?.expectedSessionKey, 'admin');
        expect(api.requests.first.requestContext?.expectedToken, 'admin-token');
        expect((api.requests.first.body as Map)['ownerType'], 'PROMOTION');
        expect((api.requests.first.body as Map)['ownerId'], 'draft-id');
        expect(adapter.requests.single.bytes, [1, 2, 3]);
      },
    );
  }

  test('invalid visibility is rejected before init upload or bytes', () async {
    final api = RecordingApiClient((_) => throw StateError('No transport'));
    final result = await ProfileMediaUploadRepositoryImpl(api).uploadAsset(
      source: ProfileUploadSource.bytes([1]),
      ownerType: 'PROMOTION',
      ownerId: 'draft',
      mediaKind: 'IMAGE',
      mimeType: 'image/jpeg',
      originalFileName: 'poster.jpg',
      visibility: 'UNLISTED',
    );
    expect(result.error?.code, 'profile_upload_visibility');
    expect(api.requests, isEmpty);
  });

  test('recovers a completed unattached draft after process restart', () async {
    final cleanupStore = MemoryPendingDraftMediaCleanupStore();
    final api = RecordingApiClient((request) {
      if (request.path == '/api/v1/user/media/init-upload') {
        return <String, dynamic>{
          'assetId': 'asset-draft',
          'uploadUrl': 'https://upload.example.test/assets/asset-draft',
        };
      }
      if (request.path == '/api/v1/user/media/complete-upload') {
        return <String, dynamic>{
          'uuid': 'asset-draft',
          'sourceUrl': 'https://cdn.example.test/asset-draft.jpg',
        };
      }
      if (request.path == '/api/v1/user/media/asset-draft') return null;
      throw StateError('Unexpected path: ${request.path}');
    });
    final adapter = _UploadAdapter(statusCode: 200);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      uploadClient: dio,
      sessionKeyProvider: () => 'account-A',
      pendingDraftCleanupStore: cleanupStore,
    );

    final uploaded = await repository.uploadAsset(
      source: ProfileUploadSource.bytes(<int>[1, 2, 3]),
      ownerType: 'STUDIO_PROFILE',
      ownerId: 'studio-1',
      mediaKind: 'IMAGE',
      mimeType: 'image/jpeg',
      originalFileName: 'room.jpg',
      attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
    );

    expect(uploaded.isSuccess, isTrue);
    expect((await cleanupStore.readAll()).single.assetId, 'asset-draft');

    final restartedRepository = ProfileMediaUploadRepositoryImpl(
      api,
      sessionKeyProvider: () => 'account-A',
      pendingDraftCleanupStore: cleanupStore,
    );
    await restartedRepository.resumePendingUploads();

    expect(await cleanupStore.readAll(), isEmpty);
    final deleteRequest = api.requests.last;
    expect(deleteRequest.method, RecordedHttpMethod.delete);
    expect(deleteRequest.path, '/api/v1/user/media/asset-draft');
    expect(deleteRequest.query, <String, dynamic>{
      'actingAsType': 'STUDIO_PROFILE',
      'actingAsId': 'studio-1',
    });
    expect(deleteRequest.requestContext?.expectedSessionKey, 'account-A');
  });

  test(
    'startup recovery clears referenced intents without deleting media',
    () async {
      final pending = PendingDraftMediaCleanup(
        sessionKey: 'account-A',
        assetId: 'asset-referenced',
        ownerType: 'STUDIO_PROFILE',
        ownerId: 'studio-1',
        createdAt: DateTime.utc(2026, 7, 21),
      );
      final cleanupStore = MemoryPendingDraftMediaCleanupStore(
        <PendingDraftMediaCleanup>[pending],
      );
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: '1823', message: 'Media is referenced'),
        ),
      );
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        sessionKeyProvider: () => 'account-A',
        pendingDraftCleanupStore: cleanupStore,
      );

      await repository.resumePendingUploads();

      expect(await cleanupStore.readAll(), isEmpty);
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'startup recovery retains transient cleanup failures for retry',
    () async {
      final pending = PendingDraftMediaCleanup(
        sessionKey: 'account-A',
        assetId: 'asset-offline',
        ownerType: 'STUDIO_PROFILE',
        ownerId: 'studio-1',
        createdAt: DateTime.utc(2026, 7, 21),
      );
      final cleanupStore = MemoryPendingDraftMediaCleanupStore(
        <PendingDraftMediaCleanup>[pending],
      );
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: 'network', message: 'Offline'),
        ),
      );
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        sessionKeyProvider: () => 'account-A',
        pendingDraftCleanupStore: cleanupStore,
      );

      await repository.resumePendingUploads();

      expect((await cleanupStore.readAll()).single.assetId, 'asset-offline');
      expect(api.requests, hasLength(1));
    },
  );

  test('recovery skips a draft leased by an active form', () async {
    final cleanupStore = MemoryPendingDraftMediaCleanupStore();
    final api = RecordingApiClient((_) => null);
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      sessionKeyProvider: () => 'account-A',
      pendingDraftCleanupStore: cleanupStore,
    );
    await repository.persistDraftCleanupIntent(
      assetId: 'asset-active',
      ownerType: 'STUDIO_PROFILE',
      ownerId: 'studio-1',
    );

    await repository.resumePendingUploads();
    expect(api.requests, isEmpty);
    expect(await cleanupStore.readAll(), hasLength(1));

    repository.releaseDraftCleanupLeases(const <String>['asset-active']);
    await repository.resumePendingUploads();
    expect(api.requests, hasLength(1));
    expect(await cleanupStore.readAll(), isEmpty);
  });

  test('deletes an owned asset with owner guard and session fence', () async {
    final api = RecordingApiClient((request) {
      expect(request.method, RecordedHttpMethod.delete);
      expect(request.path, '/api/v1/user/media/asset-1');
      expect(request.query, <String, dynamic>{
        'actingAsType': 'STUDIO_PROFILE',
        'actingAsId': 'studio-1',
      });
      expect(request.requestContext?.expectedSessionKey, 'account-A');
      return null;
    });
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      sessionKeyProvider: () => 'account-A',
    );

    final result = await repository.deleteOwnedAsset(
      assetId: ' asset-1 ',
      ownerType: 'studio_profile',
      ownerId: ' studio-1 ',
    );

    expect(result.isSuccess, isTrue);
    expect(api.requests, hasLength(1));
  });

  test('rejects invalid delete input without dispatching a request', () async {
    final api = RecordingApiClient((_) => throw StateError('unexpected'));
    final repository = ProfileMediaUploadRepositoryImpl(api);

    final result = await repository.deleteOwnedAsset(
      assetId: ' ',
      ownerType: 'STUDIO_PROFILE',
      ownerId: 'studio-1',
    );

    expect(result.error?.code, 'profile_media_delete_invalid');
    expect(api.requests, isEmpty);
  });

  test(
    'preserves guarded delete conflicts for lifecycle reconciliation',
    () async {
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: '1823', message: 'Media is referenced'),
        ),
      );
      final repository = ProfileMediaUploadRepositoryImpl(api);

      final result = await repository.deleteOwnedAsset(
        assetId: 'asset-1',
        ownerType: 'STUDIO_PROFILE',
        ownerId: 'studio-1',
      );

      expect(result.error?.code, '1823');
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'rejects empty and pre-cancelled uploads before any network call',
    () async {
      final api = RecordingApiClient((_) => throw StateError('unexpected'));
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        uploadClient: dio,
      );

      final empty = await repository.uploadAsset(
        source: ProfileUploadSource.bytes(const <int>[]),
        ownerType: 'MUSICIAN',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'empty.jpg',
      );
      final cancellation = ProfileUploadCancellation()..cancel('user');
      final cancelled = await repository.uploadAsset(
        source: ProfileUploadSource.bytes(<int>[1]),
        ownerType: 'MUSICIAN',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'cancelled.jpg',
        cancellation: cancellation,
      );

      expect(empty.error?.code, 'profile_upload_empty');
      expect(cancelled.error?.code, 'profile_upload_cancelled');
      expect(api.requests, isEmpty);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'initializes, streams bytes, and completes the upload contract',
    () async {
      final api = RecordingApiClient((request) {
        return switch (request.path) {
          '/api/v1/user/media/init-upload' => <String, dynamic>{
            'assetId': 'asset-1',
            'uploadUrl': 'https://upload.example.test/assets/asset-1',
          },
          '/api/v1/user/media/complete-upload' => <String, dynamic>{
            'uuid': 'media-1',
            'sourceUrl': 'https://cdn.example.test/media-1.jpg',
          },
          _ => throw StateError('Unexpected path: ${request.path}'),
        };
      });
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        uploadClient: dio,
      );
      final progress = <(int, int)>[];

      final result = await repository.uploadAsset(
        source: ProfileUploadSource(
          sizeBytes: 4,
          openRead: () => Stream<List<int>>.fromIterable(<List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]),
        ),
        ownerType: 'MUSICIAN',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'avatar.jpg',
        onProgress: (sent, total) => progress.add((sent, total)),
      );

      expect(result.data?.uuid, 'media-1');
      expect(result.data?.sourceUrl, 'https://cdn.example.test/media-1.jpg');
      expect(api.requests, hasLength(2));
      final initRequest = api.requests[0];
      expect(initRequest.method, RecordedHttpMethod.post);
      expect(initRequest.path, '/api/v1/user/media/init-upload');
      expect(initRequest.body, <String, dynamic>{
        'ownerType': 'MUSICIAN',
        'ownerId': 'owner-1',
        'kind': 'IMAGE',
        'visibility': 'PUBLIC',
        'contentAudience': 'MAINSTAGE',
        'mimeType': 'image/jpeg',
        'sizeBytes': 4,
        'originalFileName': 'avatar.jpg',
      });
      final completionRequest = api.requests[1];
      expect(completionRequest.method, RecordedHttpMethod.post);
      expect(completionRequest.path, '/api/v1/user/media/complete-upload');
      expect(completionRequest.body, <String, dynamic>{'assetId': 'asset-1'});
      expect(adapter.requests.single.method, 'PUT');
      expect(
        adapter.requests.single.path,
        'https://upload.example.test/assets/asset-1',
      );
      expect(adapter.requests.single.bytes, <int>[1, 2, 3, 4]);
      expect(
        adapter.requests.single.headers[Headers.contentTypeHeader],
        'image/jpeg',
      );
      expect(adapter.requests.single.headers[Headers.contentLengthHeader], 4);
      expect(progress.last, (4, 4));
    },
  );

  test(
    'retries completion with bounded backoff only while asset is not ready',
    () async {
      var completionAttempts = 0;
      final observedDelays = <Duration>[];
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-1',
            'uploadUrl': 'https://upload.example.test/assets/asset-1',
          };
        }
        if (request.path == '/api/v1/user/media/complete-upload') {
          completionAttempts++;
          if (completionAttempts < 3) {
            throw ApiException(
              const AppError(code: '1814', message: 'Media asset not ready.'),
            );
          }
          return <String, dynamic>{
            'uuid': 'media-1',
            'sourceUrl': 'https://cdn.example.test/media-1.jpg',
          };
        }
        throw StateError('Unexpected path: ${request.path}');
      });
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        uploadClient: dio,
        completionRetryDelays: const <Duration>[
          Duration(milliseconds: 250),
          Duration(milliseconds: 500),
          Duration(seconds: 1),
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

      expect(result.data?.uuid, 'media-1');
      expect(completionAttempts, 3);
      expect(observedDelays, const <Duration>[
        Duration(milliseconds: 250),
        Duration(milliseconds: 500),
      ]);
    },
  );

  test(
    'keeps verifying beyond the former short window until late completion',
    () async {
      var completionAttempts = 0;
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-late',
            'uploadUrl': 'https://upload.example.test/assets/asset-late',
          };
        }
        completionAttempts++;
        if (completionAttempts <= 7) {
          throw ApiException(
            const AppError(code: '1814', message: 'Still verifying'),
          );
        }
        return <String, dynamic>{
          'uuid': 'asset-late',
          'sourceUrl': 'https://cdn.example.test/asset-late.jpg',
        };
      });
      final adapter = _UploadAdapter(statusCode: 200);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final stages = <ProfileUploadStage>[];
      final repository = ProfileMediaUploadRepositoryImpl(
        api,
        uploadClient: dio,
        completionRetryDelays: List<Duration>.filled(8, Duration.zero),
        delay: (_) async {},
      );

      final result = await repository.uploadAsset(
        source: ProfileUploadSource.bytes(<int>[1]),
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: 'owner-1',
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'late.jpg',
        onStageChanged: stages.add,
      );

      expect(result.data?.uuid, 'asset-late');
      expect(completionAttempts, 8);
      expect(
        stages,
        containsAllInOrder(<ProfileUploadStage>[
          ProfileUploadStage.initializing,
          ProfileUploadStage.uploading,
          ProfileUploadStage.verifying,
          ProfileUploadStage.attaching,
          ProfileUploadStage.completed,
        ]),
      );
    },
  );

  test(
    'resumes persisted verification and attaches gallery exactly once',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'asset-resume',
          ownerType: 'VENUE_PROFILE',
          ownerId: 'venue-profile-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.verifying,
          attachmentIntent: const ProfileUploadAttachmentIntent.gallery(
            profileType: 'VENUE',
          ),
        ),
      ]);
      var completionCalls = 0;
      var attachmentCalls = 0;
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/complete-upload') {
          completionCalls++;
          return <String, dynamic>{
            'uuid': 'asset-resume',
            'sourceUrl': 'https://cdn.example.test/resume.jpg',
          };
        }
        if (request.path == '/api/v1/profiles/VENUE/venue-profile-1/media') {
          return <String, dynamic>{
            'videos': <Object?>[],
            'audios': <Object?>[],
          };
        }
        if (request.path == '/api/v1/profile-media') {
          attachmentCalls++;
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
      await repository.resumePendingUploads();

      expect(completionCalls, 1);
      expect(attachmentCalls, 1);
      expect(await store.readAll(), isEmpty);
    },
  );

  test(
    'repository restart recognizes an already attached persisted intent',
    () async {
      final store = MemoryPendingProfileUploadStore(<PendingProfileUpload>[
        PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'asset-attached',
          ownerType: 'MUSICIAN_PROFILE',
          ownerId: 'musician-1',
          mediaKind: 'AUDIO',
          deadline: DateTime.utc(2030),
          retryIndex: 4,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.track(
            ownerType: 'MUSICIAN_PROFILE',
            title: 'Recovered song',
          ),
          completedMediaId: 'asset-attached',
        ),
      ]);
      var attachmentPosts = 0;
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/profiles/MUSICIAN/musician-1/media') {
          return <String, dynamic>{
            'videos': <Object?>[],
            'audios': <Object?>[
              <String, dynamic>{'mediaAssetId': 'asset-attached'},
            ],
          };
        }
        attachmentPosts++;
        return null;
      });
      final restartedRepository = ProfileMediaUploadRepositoryImpl(
        api,
        pendingStore: store,
        sessionKeyProvider: () => 'account-1',
      );

      await restartedRepository.resumePendingUploads();

      expect(attachmentPosts, 0);
      expect(await store.readAll(), isEmpty);
    },
  );
}
