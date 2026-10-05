part of 'dio_api_client_contract_test.dart';

void _registerDioApiClientContract3() {
  group('listener-aware public source transport', () {
    const sourcePaths = [
      '/api/v1/profiles/MUSICIAN/artist/media',
      '/api/v1/public/media/owner/MUSICIAN_PROFILE/artist/kind/VIDEO',
      '/api/v1/public/media/owner/VENUE_PROFILE/venue/kind/IMAGE',
      '/api/v1/public/search/profiles',
      '/api/v1/public/musician-profiles/artist',
      '/api/v1/public/bands/band',
      '/api/v1/public/venue-profiles/venue',
      '/api/v1/public/studio-profiles/studio',
      '/api/v1/public/studio-profiles/studio/rooms/room/availability',
      '/api/v1/public/studio-profiles/studio/equipment/item/availability',
    ];
    for (final role in [null, 'ROLE_MUSICIAN', 'ROLE_VENUE', 'ROLE_LISTENER']) {
      test(
        '$role preserves source identity without authenticating discovery',
        () async {
          final token = role == null
              ? null
              : _jwt(subject: 'viewer', roles: [role]);
          final tokenStore = _MemoryTokenStore(token);
          final sessions = AuthSessionManager(
            tokenStore: tokenStore,
            sessionStore: _MemorySessionStore(
              const AuthSessionMetadata(accountStatus: 'ACTIVE'),
            ),
          );
          addTearDown(sessions.dispose);
          await sessions.restore();
          final adapter = _RecordingHttpClientAdapter(
            (_) => _jsonResponse(
              statusCode: 200,
              payload: {'success': true, 'data': 1},
            ),
          );
          final dio = _dio(adapter);
          addTearDown(() => _closeDio(dio, adapter));
          final client = DioApiClient(
            dio: dio,
            tokenStore: tokenStore,
            sessionManager: sessions,
          );

          for (final path in sourcePaths) {
            expect(await client.get<int>(path), 1);
            expect(
              adapter.requests.last.headers['Authorization'],
              role == 'ROLE_LISTENER' ? 'Bearer $token' : isNull,
              reason: path,
            );
          }
          for (final path in [
            '/api/v1/events',
            '/api/v1/venues',
            '/api/v1/cities',
            '/api/v1/public/backline/categories',
            '/api/v1/spotify/search/tracks',
            'https://external.example.test/api/v1/public/media/asset',
          ]) {
            expect(await client.get<int>(path), 1);
            expect(
              adapter.requests.last.headers['Authorization'],
              isNull,
              reason: path,
            );
          }
        },
      );
    }

    test(
      'real profile media fallback, gallery and search repositories send listener JWT',
      () async {
        final token = _jwt(subject: 'listener', roles: ['ROLE_LISTENER']);
        final tokenStore = _MemoryTokenStore(token);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(
            const AuthSessionMetadata(accountStatus: 'ACTIVE'),
          ),
        );
        addTearDown(sessions.dispose);
        await sessions.restore();
        final adapter = _RecordingHttpClientAdapter(
          (options) => _jsonResponse(
            statusCode: 200,
            payload: {
              'success': true,
              'data': options.path.endsWith('/media')
                  ? {'videos': [], 'audios': []}
                  : options.path.endsWith('/search/profiles')
                  ? []
                  : {'content': []},
            },
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        final media = await ProfileMediaRepositoryImpl(
          client,
        ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'artist');
        final photos = await MediaGalleryRepositoryImpl(
          client,
        ).listPublicImages(ownerType: 'MUSICIAN_PROFILE', ownerId: 'artist');
        final search = await ProfileSearchRepositoryImpl(
          client,
          sessions: sessions,
        ).searchProfiles('artist');
        expect(media.isSuccess, isTrue);
        expect(photos.isSuccess, isTrue);
        expect(search.isSuccess, isTrue);
        expect(adapter.requests.map((request) => request.path), [
          '/api/v1/profiles/MUSICIAN/artist/media',
          '/api/v1/public/media/owner/MUSICIAN_PROFILE/artist/kind/VIDEO',
          '/api/v1/public/media/owner/MUSICIAN_PROFILE/artist/kind/IMAGE',
          '/api/v1/public/search/profiles',
        ]);
        for (final request in adapter.requests) {
          expect(request.headers['Authorization'], 'Bearer $token');
        }
      },
    );

    for (final initialRole in [null, 'ROLE_MUSICIAN', 'ROLE_LISTENER']) {
      test(
        '$initialRole source response is discarded before decoding after account change',
        () async {
          final token = initialRole == null
              ? null
              : _jwt(subject: 'first', roles: [initialRole]);
          final tokenStore = _MemoryTokenStore(token);
          final sessions = AuthSessionManager(
            tokenStore: tokenStore,
            sessionStore: _MemorySessionStore(
              const AuthSessionMetadata(accountStatus: 'ACTIVE'),
            ),
          );
          addTearDown(sessions.dispose);
          await sessions.restore();
          final arrived = Completer<void>();
          final response = Completer<void>();
          final adapter = _RecordingHttpClientAdapter((_) async {
            arrived.complete();
            await response.future;
            return _jsonResponse(
              statusCode: 200,
              payload: {'success': true, 'data': 7},
            );
          });
          final dio = _dio(adapter);
          addTearDown(() => _closeDio(dio, adapter));
          final client = DioApiClient(
            dio: dio,
            tokenStore: tokenStore,
            sessionManager: sessions,
          );
          var decoded = false;
          final pending = expectLater(
            client.get<int>(
              sourcePaths.first,
              decoder: (data) {
                decoded = true;
                return data! as int;
              },
            ),
            throwsA(
              isA<ApiException>().having(
                (e) => e.error.code,
                'code',
                'api_session_fence',
              ),
            ),
          );
          await arrived.future;
          await sessions.startSession(
            token: _jwt(
              subject: initialRole == 'ROLE_MUSICIAN' ? 'first' : 'second',
              roles: ['ROLE_LISTENER'],
            ),
            username: 'second',
            accountStatus: 'ACTIVE',
          );
          // Exercise ABA too: a const guest snapshot must never revive its read.
          if (initialRole == null) await sessions.logout();
          response.complete();
          await pending;
          expect(decoded, isFalse);
        },
      );
    }

    test(
      'source dispatch rejects a session change while credentials are loading',
      () async {
        final token = _jwt(subject: 'first', roles: ['ROLE_LISTENER']);
        final tokenStore = _BarrierTokenStore(token);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(
            const AuthSessionMetadata(accountStatus: 'ACTIVE'),
          ),
        );
        addTearDown(sessions.dispose);
        await sessions.restore();
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 200,
            payload: {'success': true, 'data': 1},
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        tokenStore.armBarrier();
        final pending = expectLater(
          client.get<int>(sourcePaths.first),
          throwsA(
            isA<ApiException>().having(
              (e) => e.error.code,
              'code',
              'api_session_fence',
            ),
          ),
        );
        await tokenStore.readStarted.future;
        await sessions.startSession(
          token: _jwt(subject: 'second', roles: ['ROLE_MUSICIAN']),
          username: 'second',
          accountStatus: 'ACTIVE',
        );
        tokenStore.releaseRead();
        await pending;
        expect(adapter.requests, isEmpty);
        expect(sessions.session.userId, 'second');
      },
    );

    test(
      'listener source explicit request context attaches JWT and a 401 rejects that session',
      () async {
        final token = _jwt(subject: 'listener', roles: ['ROLE_LISTENER']);
        final tokenStore = _MemoryTokenStore(token);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(
            const AuthSessionMetadata(accountStatus: 'ACTIVE'),
          ),
        );
        addTearDown(sessions.dispose);
        await sessions.restore();
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 401,
            payload: {'code': 401, 'message': 'Rejected'},
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        await expectLater(
          client.request<Object?>(
            ApiHttpMethod.get,
            sourcePaths.first,
            requestContext: ApiRequestContext(
              expectedSessionKey: 'listener',
              expectedToken: token,
            ),
          ),
          throwsA(isA<ApiException>()),
        );
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer $token',
        );
        expect(sessions.session.isAuthenticated, isFalse);
        expect(tokenStore.value, isNull);
      },
    );

    test(
      'source 1308 keeps listener identity and restores onboarding gate',
      () async {
        final token = _jwt(subject: 'listener', roles: ['ROLE_LISTENER']);
        final tokenStore = _MemoryTokenStore(token);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(
            const AuthSessionMetadata(accountStatus: 'ACTIVE'),
          ),
        );
        addTearDown(sessions.dispose);
        await sessions.restore();
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 428,
            payload: {'code': 1308, 'message': 'Choice required'},
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        await expectLater(
          client.get<Object?>(sourcePaths.first),
          throwsA(isA<ApiException>()),
        );
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer $token',
        );
        expect(sessions.session.requiresListenerProfileChoice, isTrue);
        expect(sessions.session.isAuthenticated, isTrue);
      },
    );

    test(
      'missing listener credentials cannot silently become a guest source read',
      () async {
        final token = _jwt(subject: 'listener', roles: ['ROLE_LISTENER']);
        final tokenStore = _MemoryTokenStore(token);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(
            const AuthSessionMetadata(accountStatus: 'ACTIVE'),
          ),
        );
        addTearDown(sessions.dispose);
        await sessions.restore();
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 200,
            payload: {'success': true, 'data': 1},
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        tokenStore.value = null;
        await expectLater(
          client.get<int>(sourcePaths.first),
          throwsA(
            isA<ApiException>().having(
              (e) => e.error.code,
              'code',
              'api_session_fence',
            ),
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test(
      'late authenticated public source 401 cannot log out a replacement listener',
      () async {
        final token = _jwt(subject: 'first', roles: ['ROLE_LISTENER']);
        final tokenStore = _MemoryTokenStore(token);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(
            const AuthSessionMetadata(accountStatus: 'ACTIVE'),
          ),
        );
        addTearDown(sessions.dispose);
        await sessions.restore();
        final arrived = Completer<void>();
        final response = Completer<void>();
        final adapter = _RecordingHttpClientAdapter((_) async {
          arrived.complete();
          await response.future;
          return _jsonResponse(
            statusCode: 401,
            payload: {'code': 401, 'message': 'Rejected'},
          );
        });
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        final pending = expectLater(
          client.get<Object?>(sourcePaths.first),
          throwsA(isA<ApiException>()),
        );
        await arrived.future;
        await sessions.startSession(
          token: _jwt(subject: 'second', roles: ['ROLE_LISTENER']),
          username: 'second',
          accountStatus: 'ACTIVE',
        );
        response.complete();
        await pending;
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer $token',
        );
        expect(sessions.session.userId, 'second');
        expect(sessions.session.isAuthenticated, isTrue);
      },
    );

    test(
      'forced guest source strips headers and cannot downgrade a listener',
      () async {
        final tokenStore = _MemoryTokenStore(null);
        final sessions = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: _MemorySessionStore(null),
        );
        addTearDown(sessions.dispose);
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: 200,
            payload: {'success': true, 'data': 1},
          ),
        );
        final dio = _dio(adapter);
        dio.options.headers['authorization'] = 'stale';
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: tokenStore,
          sessionManager: sessions,
        );
        expect(
          await client.request<int>(
            ApiHttpMethod.get,
            sourcePaths.first,
            requestContext: const ApiRequestContext(requireGuestSession: true),
          ),
          1,
        );
        expect(
          adapter.requests.single.headers.keys.any(
            (key) => key.toLowerCase() == 'authorization',
          ),
          isFalse,
        );
        await sessions.startSession(
          token: _jwt(subject: 'listener', roles: ['ROLE_LISTENER']),
          username: 'listener',
          accountStatus: 'ACTIVE',
        );
        await expectLater(
          client.request<int>(
            ApiHttpMethod.get,
            sourcePaths.first,
            requestContext: const ApiRequestContext(requireGuestSession: true),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.error.code,
              'code',
              'api_session_fence',
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
        expect(sessions.session.isAuthenticated, isTrue);
      },
    );
  });

  group('DioApiClient transport contract', () {
    _registerDioApiClientTransportContract1();
    _registerDioApiClientTransportContract2();
  });
}
