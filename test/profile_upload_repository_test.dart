import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_upload_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_draft_media_cleanup_store.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_profile_upload_store.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

import 'support/recording_api_client.dart';

part 'support/profile_upload_repository_test_support.dart';

void main() {
  group('ProfileMediaUploadRepositoryImpl', () {
    test(
      'recovers a completed unattached draft after process restart',
      () async {
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
      },
    );

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

    test(
      'rejects invalid delete input without dispatching a request',
      () async {
        final api = RecordingApiClient((_) => throw StateError('unexpected'));
        final repository = ProfileMediaUploadRepositoryImpl(api);

        final result = await repository.deleteOwnedAsset(
          assetId: ' ',
          ownerType: 'STUDIO_PROFILE',
          ownerId: 'studio-1',
        );

        expect(result.error?.code, 'profile_media_delete_invalid');
        expect(api.requests, isEmpty);
      },
    );

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
            attachmentIntent:
                const ProfileUploadAttachmentIntent.profilePicture(
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
      'Studio audio recovery checks and attaches to Studio tracks',
      () async {
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
            return <String, dynamic>{
              'videos': <Object?>[],
              'audios': <Object?>[],
            };
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
      },
    );

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
          throw ApiException(
            const AppError(code: '1814', message: 'Not ready'),
          );
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

    test('recovers S3 commit when the client loses the PUT response', () async {
      final store = MemoryPendingProfileUploadStore();
      final completionStarted = Completer<void>();
      final allowCompletion = Completer<Object?>();
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/user/media/init-upload') {
          return <String, dynamic>{
            'assetId': 'asset-response-lost',
            'uploadUrl':
                'https://upload.example.test/assets/asset-response-lost',
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
  });
}
