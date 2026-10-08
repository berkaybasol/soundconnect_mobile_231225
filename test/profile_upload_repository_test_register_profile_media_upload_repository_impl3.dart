part of 'profile_upload_repository_test.dart';

void _registerProfileMediaUploadRepositoryImpl3() {
  test('recovers S3 commit when the client loses the PUT response', () async {
    final store = MemoryPendingProfileUploadStore();
    final completionStarted = Completer<void>();
    final allowCompletion = Completer<Object?>();
    final api = RecordingApiClient((request) {
      if (request.path == '/api/v1/user/media/init-upload') {
        return <String, dynamic>{
          'assetId': 'asset-response-lost',
          'uploadUrl': 'https://upload.example.test/assets/asset-response-lost',
        };
      }
      if (!completionStarted.isCompleted) completionStarted.complete();
      return allowCompletion.future;
    });
    final adapter = _CommittedThenResponseLostUploadAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final repository = ProfileMediaUploadRepositoryImpl(
      api,
      uploadClient: dio,
      pendingStore: store,
    );
    final recovered = repository.recoveryEvents.firstWhere(
      (event) => event.isSuccess,
    );

    final resultFuture = repository.uploadAsset(
      source: ProfileUploadSource.bytes(<int>[1, 2, 3, 4]),
      ownerType: 'MUSICIAN_PROFILE',
      ownerId: 'owner-1',
      mediaKind: 'IMAGE',
      mimeType: 'image/jpeg',
      originalFileName: 'response-lost.jpg',
    );
    await completionStarted.future.timeout(const Duration(seconds: 2));

    final ambiguous = await store.readAll();
    expect(adapter.committedBytes, <int>[1, 2, 3, 4]);
    expect(ambiguous, hasLength(1));
    expect(ambiguous.single.phase, PendingProfileUploadPhase.uploading);
    expect((await resultFuture).error?.code, 'profile_upload_transport');

    allowCompletion.complete(<String, dynamic>{
      'uuid': 'asset-response-lost',
      'sourceUrl': 'https://cdn.example.test/response-lost.jpg',
    });
    await recovered.timeout(const Duration(seconds: 2));
    expect(await store.readAll(), isEmpty);
  });

  test('preserves API errors and maps upload transport failures', () async {
    const typed = AppError(code: 'quota', message: 'Quota exceeded');
    final typedApi = RecordingApiClient((_) => throw ApiException(typed));
    final typedAdapter = _UploadAdapter(statusCode: 200);
    final typedDio = Dio()..httpClientAdapter = typedAdapter;
    addTearDown(() => typedDio.close(force: true));

    final typedResult =
        await ProfileMediaUploadRepositoryImpl(
          typedApi,
          uploadClient: typedDio,
        ).uploadAsset(
          source: ProfileUploadSource.bytes(<int>[1]),
          ownerType: 'MUSICIAN',
          ownerId: 'owner-1',
          mediaKind: 'IMAGE',
          mimeType: 'image/jpeg',
          originalFileName: 'avatar.jpg',
        );
    expect(typedResult.error, same(typed));
    expect(typedAdapter.requests, isEmpty);

    final pendingStore = MemoryPendingProfileUploadStore();
    final uploadApi = RecordingApiClient((request) {
      if (request.path == '/api/v1/user/media/init-upload') {
        return <String, dynamic>{
          'assetId': 'asset-1',
          'uploadUrl': 'https://upload.example.test/assets/asset-1',
        };
      }
      throw ApiException(const AppError(code: 'network', message: 'Offline'));
    });
    final failingAdapter = _UploadAdapter(statusCode: 503);
    final failingDio = Dio()..httpClientAdapter = failingAdapter;
    addTearDown(() => failingDio.close(force: true));
    final transportResult =
        await ProfileMediaUploadRepositoryImpl(
          uploadApi,
          uploadClient: failingDio,
          pendingStore: pendingStore,
        ).uploadAsset(
          source: ProfileUploadSource.bytes(<int>[1]),
          ownerType: 'MUSICIAN',
          ownerId: 'owner-1',
          mediaKind: 'IMAGE',
          mimeType: 'image/jpeg',
          originalFileName: 'avatar.jpg',
        );

    expect(transportResult.error?.code, 'profile_upload_transport');
    expect(failingAdapter.requests, hasLength(1));
    expect(uploadApi.requests.map((request) => request.path), <String>[
      '/api/v1/user/media/init-upload',
      '/api/v1/user/media/complete-upload',
    ]);
    final retained = await pendingStore.readAll();
    expect(retained, hasLength(1));
    expect(retained.single.phase, PendingProfileUploadPhase.uploading);
  });
}
