part of 'dio_api_client_contract_test.dart';

void _registerDioApiClientTransportContract1() {
  test('login recovery crosses HTTP 403 without creating a session', () async {
    final adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 403,
        payload: {
          'code': 1113,
          'message': 'Email verification is required',
          'details': ['pending@example.com'],
        },
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final tokenStore = _MemoryTokenStore(null);
    final sessionStore = _MemorySessionStore(null);
    final sessions = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    );
    addTearDown(sessions.dispose);
    final repository = AuthRepositoryImpl(
      DioApiClient(dio: dio, tokenStore: tokenStore, sessionManager: sessions),
    );

    final result = await repository.login(
      username: 'pending',
      password: 'test-password',
    );

    expect(result.isSuccess, isFalse);
    expect(result.error?.code, 'auth_email_verification_required');
    expect(result.error?.details, ['pending@example.com']);
    expect(result.error?.message, contains('e-posta doğrulamasını'));
    expect(result.data, isNull);
    expect(sessions.session.isAuthenticated, isFalse);
    expect(tokenStore.value, isNull);
    expect(sessionStore.value, isNull);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/api/v1/auth/login');
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('announcement attribution travels only on its fenced request', () async {
    final adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 200,
        payload: {
          'success': true,
          'code': 200,
          'data': {'value': '7'},
        },
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final token = _jwt(subject: 'account-a', roles: const ['ROLE_MUSICIAN']);
    final client = DioApiClient(dio: dio, tokenStore: _MemoryTokenStore(token));
    await client.request<int>(
      ApiHttpMethod.post,
      '/api/v1/likes',
      decoder: _decodeValue,
      requestContext: ApiRequestContext(
        expectedSessionKey: 'account-a',
        expectedToken: token,
        announcementSource: 'FEED',
      ),
    );
    await client.get<int>('/api/v1/events/discover', decoder: _decodeValue);
    expect(adapter.requests.first.headers['X-Announcement-Source'], 'FEED');
    expect(
      adapter.requests.last.headers.containsKey('X-Announcement-Source'),
      isFalse,
    );
    for (final context in [
      const ApiRequestContext(announcementSource: 'FEED'),
      const ApiRequestContext(
        expectedSessionKey: 'account-a',
        announcementSource: 'ADMIN_PREVIEW',
      ),
      const ApiRequestContext(
        expectedSessionKey: 'account-a',
        requireGuestSession: true,
        announcementSource: 'DIRECTORY',
      ),
    ]) {
      await expectLater(
        client.request<int>(
          ApiHttpMethod.post,
          '/api/v1/likes',
          decoder: _decodeValue,
          requestContext: context,
        ),
        throwsA(isA<ApiException>()),
      );
    }
    await expectLater(
      client.request<int>(
        ApiHttpMethod.post,
        '/api/v1/likes',
        decoder: _decodeValue,
        requestContext: ApiRequestContext(
          expectedSessionKey: 'account-b',
          expectedToken: token,
          announcementSource: 'FEED',
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, hasLength(2));
  });

  test(
    'authenticates private requests but leaves public requests clean',
    () async {
      final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
        (RequestOptions options) => _jsonResponse(
          statusCode: 200,
          payload: <String, dynamic>{
            'success': true,
            'code': 200,
            'data': <String, dynamic>{
              'value': options.path.contains('private') ? '7' : '8',
            },
          },
        ),
      );
      final Dio dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final _MemoryTokenStore tokenStore = _MemoryTokenStore('access-token');
      final DioApiClient client = DioApiClient(
        dio: dio,
        tokenStore: tokenStore,
      );

      final int privateValue = await client.get<int>(
        '/api/v1/private/value',
        decoder: _decodeValue,
      );
      final int publicValue = await client.get<int>(
        '/api/v1/events/discover',
        decoder: _decodeValue,
      );

      expect(privateValue, 7);
      expect(publicValue, 8);
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer access-token',
      );
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(tokenStore.readCount, 1);
    },
  );

  test('decodes a successful envelope through the supplied decoder', () async {
    final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 200,
        payload: <String, dynamic>{
          'success': true,
          'message': 'ok',
          'code': 200,
          'data': <String, dynamic>{'value': '42'},
        },
      ),
    );
    final Dio dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final DioApiClient client = DioApiClient(
      dio: dio,
      tokenStore: _MemoryTokenStore(null),
    );

    final int value = await client.get<int>(
      '/api/v1/events/value',
      decoder: _decodeValue,
    );

    expect(value, 42);
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/api/v1/events/value');
  });

  test('unwraps scalar and null auth response data', () async {
    final adapter = _RecordingHttpClientAdapter(
      (options) => _jsonResponse(
        statusCode: 200,
        payload: <String, dynamic>{
          'success': true,
          'message': 'ok',
          'code': 200,
          'data': options.path == '/api/v1/users/me/username'
              ? 'new-name'
              : null,
        },
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final client = DioApiClient(dio: dio, tokenStore: _MemoryTokenStore(null));

    final username = await client.request<String>(
      ApiHttpMethod.patch,
      '/api/v1/users/me/username',
      body: const <String, String>{'username': 'new-name'},
      decoder: (json) => json?.toString() ?? '',
    );
    final resetRequest = await client.request<Object?>(
      ApiHttpMethod.post,
      '/api/v1/auth/forgot-password',
      body: const <String, String>{'email': 'user@example.com'},
      decoder: (_) => null,
    );

    expect(username, 'new-name');
    expect(resetRequest, isNull);
    expect(adapter.requests.map((request) => request.method), <String>[
      'PATCH',
      'POST',
    ]);
  });

  test('maps a rejected success-status envelope to ApiException', () async {
    final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 200,
        payload: <String, dynamic>{
          'success': false,
          'message': 'Conflict',
          'code': 409,
          'data': null,
        },
      ),
    );
    final Dio dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final DioApiClient client = DioApiClient(
      dio: dio,
      tokenStore: _MemoryTokenStore(null),
    );

    await expectLater(
      client.get<Object?>('/api/v1/events/conflict'),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.error.code, 'code', '409')
            .having(
              (ApiException error) => error.error.message,
              'message',
              'Conflict',
            ),
      ),
    );
  });

  test(
    'maps HTTP error details, code, and message deterministically',
    () async {
      final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 422,
          payload: <String, dynamic>{
            'code': 9251,
            'message': 'Invalid parameter',
            'details': <String>['Neighborhood is invalid', 'Second detail'],
          },
        ),
      );
      final Dio dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final DioApiClient client = DioApiClient(
        dio: dio,
        tokenStore: _MemoryTokenStore(null),
      );

      await expectLater(
        client.get<Object?>('/api/v1/events/invalid'),
        throwsA(
          isA<ApiException>()
              .having((ApiException error) => error.error.code, 'code', '9251')
              .having(
                (ApiException error) => error.error.message,
                'message',
                'Neighborhood is invalid',
              )
              .having(
                (ApiException error) => error.error.details,
                'details',
                <String>['Neighborhood is invalid', 'Second detail'],
              ),
        ),
      );
    },
  );

  test('preserves a string Collab conflict code from an HTTP error', () async {
    final adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 409,
        payload: <String, dynamic>{
          'code': '9317',
          'message': 'Kayıt değişti; yenileyip tekrar deneyin.',
        },
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final client = DioApiClient(dio: dio, tokenStore: _MemoryTokenStore(null));

    await expectLater(
      client.get<Object?>('/api/v1/collabs/listing-1'),
      throwsA(
        isA<ApiException>().having((error) => error.error.code, 'code', '9317'),
      ),
    );
  });

  test('401 rejects only the token attached to a private request', () async {
    final String token = _jwt(
      subject: 'user-1',
      roles: const <String>['ROLE_LISTENER'],
    );
    final _MemoryTokenStore tokenStore = _MemoryTokenStore(token);
    final _MemorySessionStore sessionStore = _MemorySessionStore(
      const AuthSessionMetadata(accountStatus: 'ACTIVE'),
    );
    var sessionEndedCount = 0;
    final AuthSessionManager sessionManager = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: sessionStore,
      onSessionEnded: () async => sessionEndedCount += 1,
    );
    addTearDown(sessionManager.dispose);
    await sessionManager.restore();
    final _RecordingHttpClientAdapter adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 401,
        payload: <String, dynamic>{
          'code': 401,
          'message': 'Unauthorized',
          'details': <String>[],
        },
      ),
    );
    final Dio dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final DioApiClient client = DioApiClient(
      dio: dio,
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );

    await expectLater(
      client.get<Object?>('/api/v1/events/discover'),
      throwsA(isA<ApiException>()),
    );
    expect(sessionManager.session.isAuthenticated, isTrue);
    expect(sessionEndedCount, 0);

    await expectLater(
      client.get<Object?>('/api/v1/private/profile'),
      throwsA(isA<ApiException>()),
    );

    expect(sessionManager.session.isAuthenticated, isFalse);
    expect(sessionEndedCount, 1);
    expect(tokenStore.value, isNull);
    expect(sessionStore.value, isNull);
    expect(
      adapter.requests.first.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(adapter.requests.last.headers['Authorization'], 'Bearer $token');
  });

  test(
    'listener public projection sends JWT and rejects its session on 401',
    () async {
      final token = _jwt(
        subject: 'listener-user',
        roles: const <String>['ROLE_LISTENER'],
      );
      final tokenStore = _MemoryTokenStore(token);
      final sessionStore = _MemorySessionStore(
        const AuthSessionMetadata(accountStatus: 'ACTIVE'),
      );
      var sessionEndedCount = 0;
      final sessionManager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
        onSessionEnded: () async => sessionEndedCount += 1,
      );
      addTearDown(sessionManager.dispose);
      await sessionManager.restore();
      final adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 401,
          payload: const <String, dynamic>{
            'code': 401,
            'message': 'Unauthorized',
            'details': <String>[],
          },
        ),
      );
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final client = DioApiClient(
        dio: dio,
        tokenStore: tokenStore,
        sessionManager: sessionManager,
      );

      await expectLater(
        client.get<Object?>('/api/v1/public/listener-profiles/profile-1'),
        throwsA(isA<ApiException>()),
      );

      expect(adapter.requests.single.headers['Authorization'], 'Bearer $token');
      expect(sessionManager.session.isAuthenticated, isFalse);
      expect(sessionEndedCount, 1);
      expect(tokenStore.value, isNull);
      expect(sessionStore.value, isNull);
    },
  );

  test(
    '1308 repairs listener onboarding metadata without logging out',
    () async {
      final token = _jwt(
        subject: 'listener-user',
        roles: const <String>['ROLE_LISTENER'],
      );
      final tokenStore = _MemoryTokenStore(token);
      final sessionStore = _MemorySessionStore(
        const AuthSessionMetadata(
          accountStatus: 'ACTIVE',
          requiresListenerProfileChoice: false,
        ),
      );
      final sessionManager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
      );
      addTearDown(sessionManager.dispose);
      await sessionManager.restore();
      final adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 428,
          payload: const <String, dynamic>{
            'code': 1308,
            'message': 'Listener profile visibility choice is required',
          },
        ),
      );
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final client = DioApiClient(
        dio: dio,
        tokenStore: tokenStore,
        sessionManager: sessionManager,
      );

      await expectLater(
        client.get<Object?>('/api/v1/private/profile'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.error.code,
            'code',
            '1308',
          ),
        ),
      );

      expect(sessionManager.session.isAuthenticated, isTrue);
      expect(sessionManager.session.requiresListenerProfileChoice, isTrue);
      expect(sessionStore.value?.requiresListenerProfileChoice, isTrue);
      expect(tokenStore.value, token);
    },
  );

  test(
    'session fence rejects A recovery after token read crosses into B',
    () async {
      final tokenA = _jwt(
        subject: 'account-A',
        roles: const <String>['ROLE_LISTENER'],
      );
      final tokenB = _jwt(
        subject: 'account-B',
        roles: const <String>['ROLE_LISTENER'],
      );
      final tokenStore = _BarrierTokenStore(tokenA);
      final sessionStore = _MemorySessionStore(
        const AuthSessionMetadata(accountStatus: 'ACTIVE'),
      );
      final sessionManager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
      );
      addTearDown(sessionManager.dispose);
      await sessionManager.restore();

      final adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 200,
          payload: <String, dynamic>{
            'success': true,
            'code': 200,
            'data': null,
          },
        ),
      );
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final client = DioApiClient(
        dio: dio,
        tokenStore: tokenStore,
        sessionManager: sessionManager,
      );

      tokenStore.armBarrier();
      final request = client.request<Object?>(
        ApiHttpMethod.post,
        '/api/v1/user/media/complete-upload',
        body: const <String, String>{'assetId': 'asset-A'},
        requestContext: const ApiRequestContext(
          expectedSessionKey: 'account-A',
        ),
      );
      await tokenStore.readStarted.future.timeout(const Duration(seconds: 2));

      await sessionManager.startSession(
        token: tokenB,
        username: 'account-B',
        accountStatus: 'ACTIVE',
      );
      final fenced = expectLater(
        request,
        throwsA(
          isA<ApiException>().having(
            (error) => error.error.code,
            'code',
            'api_session_fence',
          ),
        ),
      );
      tokenStore.releaseRead();

      await fenced;
      expect(sessionManager.session.userId, 'account-B');
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'guest fence dispatches without authorization while still guest',
    () async {
      final tokenStore = _MemoryTokenStore(null);
      final adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 202,
          payload: const {'success': true, 'data': null},
        ),
      );
      final dio = _dio(adapter);
      dio.options.headers['Authorization'] = 'stale-default-header';
      addTearDown(() => _closeDio(dio, adapter));
      final client = DioApiClient(dio: dio, tokenStore: tokenStore);

      await client.request<Object?>(
        ApiHttpMethod.post,
        '/api/v1/analytics/observations',
        requestContext: const ApiRequestContext(requireGuestSession: true),
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers['Authorization'], isNull);
    },
  );

  test('guest fence rejects login completed during token read', () async {
    final tokenStore = _BarrierTokenStore(null);
    final sessionManager = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: _MemorySessionStore(null),
    );
    addTearDown(sessionManager.dispose);
    final adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 202,
        payload: const {'success': true, 'data': null},
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final client = DioApiClient(
      dio: dio,
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );
    tokenStore.armBarrier();
    final request = client.request<Object?>(
      ApiHttpMethod.post,
      '/api/v1/analytics/observations',
      requestContext: const ApiRequestContext(requireGuestSession: true),
    );
    await tokenStore.readStarted.future;
    await sessionManager.startSession(
      token: _jwt(subject: 'new-account', roles: const ['ROLE_LISTENER']),
      username: 'new-account',
      accountStatus: 'ACTIVE',
    );
    final fenced = expectLater(
      request,
      throwsA(
        isA<ApiException>().having(
          (error) => error.error.code,
          'code',
          'api_session_fence',
        ),
      ),
    );
    tokenStore.releaseRead();
    await fenced;
    expect(adapter.requests, isEmpty);
  });

  test(
    'guest fence rejects authenticated manager despite empty store',
    () async {
      final tokenStore = _MemoryTokenStore(null);
      final sessionManager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: _MemorySessionStore(null),
      );
      addTearDown(sessionManager.dispose);
      await sessionManager.startSession(
        token: _jwt(subject: 'account-A', roles: const ['ROLE_LISTENER']),
        username: 'account-A',
        accountStatus: 'ACTIVE',
      );
      tokenStore.value = null;
      final adapter = _RecordingHttpClientAdapter(
        (_) => _jsonResponse(
          statusCode: 202,
          payload: const {'success': true, 'data': null},
        ),
      );
      final dio = _dio(adapter);
      addTearDown(() => _closeDio(dio, adapter));
      final client = DioApiClient(
        dio: dio,
        tokenStore: tokenStore,
        sessionManager: sessionManager,
      );
      await expectLater(
        client.request<Object?>(
          ApiHttpMethod.post,
          '/api/v1/analytics/observations',
          requestContext: const ApiRequestContext(requireGuestSession: true),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.error.code,
            'code',
            'api_session_fence',
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );
}
