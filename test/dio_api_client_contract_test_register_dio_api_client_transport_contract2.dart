part of 'dio_api_client_contract_test.dart';

void _registerDioApiClientTransportContract2() {
  test('conflicting guest and user fences never dispatch', () async {
    final adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 202,
        payload: const {'success': true, 'data': null},
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final client = DioApiClient(dio: dio, tokenStore: _MemoryTokenStore(null));
    await expectLater(
      client.request<Object?>(
        ApiHttpMethod.post,
        '/api/v1/analytics/observations',
        requestContext: const ApiRequestContext(
          expectedSessionKey: 'account-A',
          requireGuestSession: true,
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'transient analytics errors preserve bounded Retry-After metadata',
    () async {
      for (final status in [429, 503]) {
        final adapter = _RecordingHttpClientAdapter(
          (_) => _jsonResponse(
            statusCode: status,
            payload: {
              'code': status == 429 ? 9912 : 9913,
              'message': 'Retry later',
            },
            extraHeaders: const {
              'retry-after': ['120'],
            },
          ),
        );
        final dio = _dio(adapter);
        addTearDown(() => _closeDio(dio, adapter));
        final client = DioApiClient(
          dio: dio,
          tokenStore: _MemoryTokenStore(null),
        );
        await expectLater(
          client.post<Object?>('/api/v1/analytics/observations'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.error.retryAfter,
              'retryAfter',
              const Duration(minutes: 2),
            ),
          ),
        );
      }
    },
  );

  test('non-transient errors do not acquire Retry-After metadata', () async {
    final adapter = _RecordingHttpClientAdapter(
      (_) => _jsonResponse(
        statusCode: 401,
        payload: const {'code': 401, 'message': 'Unauthorized'},
        extraHeaders: const {
          'retry-after': ['120'],
        },
      ),
    );
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final client = DioApiClient(dio: dio, tokenStore: _MemoryTokenStore(null));
    await expectLater(
      client.post<Object?>('/api/v1/analytics/observations'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.error.retryAfter,
          'retryAfter',
          isNull,
        ),
      ),
    );
  });

  test(
    'Retry-After delta and HTTP dates reject malformed and clamp long delays',
    () {
      final now = DateTime.utc(2026, 9, 8, 12);
      expect(parseApiRetryAfter('60', now: now), const Duration(minutes: 1));
      expect(parseApiRetryAfter('0', now: now), Duration.zero);
      expect(
        parseApiRetryAfter('999999999999999999999999', now: now),
        const Duration(hours: 1),
      );
      expect(
        parseApiRetryAfter('Tue, 08 Sep 2026 12:02:00 GMT', now: now),
        const Duration(minutes: 2),
      );
      expect(
        parseApiRetryAfter('Wed, 09 Sep 2026 12:02:00 GMT', now: now),
        const Duration(hours: 1),
      );
      for (final raw in [
        null,
        '',
        '-1',
        '1.5',
        'tomorrow',
        'Tue, 08 Sep 2026 11:59:00 GMT',
        'Tue, 32 Sep 2026 12:00:00 GMT',
        'Tue, 08 Sep 2026 25:00:00 GMT',
      ]) {
        expect(parseApiRetryAfter(raw, now: now), isNull, reason: '$raw');
      }
    },
  );

  test('late 1308 from account A cannot mark account B as pending', () async {
    final tokenA = _jwt(
      subject: 'account-A',
      roles: const <String>['ROLE_LISTENER'],
    );
    final tokenB = _jwt(
      subject: 'account-B',
      roles: const <String>['ROLE_LISTENER'],
    );
    final tokenStore = _MemoryTokenStore(tokenA);
    final sessionStore = _MemorySessionStore(
      const AuthSessionMetadata(accountStatus: 'ACTIVE'),
    );
    final sessionManager = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    );
    addTearDown(sessionManager.dispose);
    await sessionManager.restore();
    final requestArrived = Completer<void>();
    final releaseResponse = Completer<void>();
    final adapter = _RecordingHttpClientAdapter((_) async {
      requestArrived.complete();
      await releaseResponse.future;
      return _jsonResponse(
        statusCode: 428,
        payload: const <String, dynamic>{
          'code': 1308,
          'message': 'Choice required',
        },
      );
    });
    final dio = _dio(adapter);
    addTearDown(() => _closeDio(dio, adapter));
    final client = DioApiClient(
      dio: dio,
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );

    final request = expectLater(
      client.get<Object?>('/api/v1/private/profile'),
      throwsA(isA<ApiException>()),
    );
    await requestArrived.future;
    await sessionManager.startSession(
      token: tokenB,
      username: 'account-B',
      accountStatus: 'ACTIVE',
    );
    releaseResponse.complete();
    await request;

    expect(sessionManager.session.userId, 'account-B');
    expect(sessionManager.session.requiresListenerProfileChoice, isFalse);
    expect(sessionStore.value?.requiresListenerProfileChoice, isFalse);
  });
}
