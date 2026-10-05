part of 'listener_profile_ui_test.dart';

class _FixedPublicListenerRepository extends ListenerProfileRepository {
  const _FixedPublicListenerRepository(this.profile);

  final ListenerPublicProfile profile;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    return const Result.failure(
      AppError(code: 'not_used', message: 'Not used by this test'),
    );
  }

  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(
    String profileId,
  ) async {
    return Result.success(profile);
  }
}

class _FixedOwnerListenerRepository extends ListenerProfileRepository {
  const _FixedOwnerListenerRepository(this.profile);

  final ListenerProfile profile;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async =>
      Result.success(profile);
}

class _GhostRaceFollowRepository implements FollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String userId) async {
    return const Result.success(0);
  }

  @override
  Future<Result<int>> getFollowingCount(String userId) async {
    return const Result.success(0);
  }

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    return const Result.success(false);
  }

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) async {
    return const Result.failure(
      AppError(code: '1206', message: 'Hayalet profiller takipçi kabul etmez.'),
    );
  }

  @override
  Future<Result<void>> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    return const Result.success(null);
  }
}

Future<void> _registerViewerSession(String userId) async {
  final manager = AuthSessionManager(
    tokenStore: _NoopTokenStore(),
    sessionStore: _NoopAuthSessionStore(),
  );
  final expiresAt =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      Duration.millisecondsPerSecond;
  final encodedHeader = base64Url.encode(
    utf8.encode(jsonEncode(const <String, Object>{'alg': 'none'})),
  );
  final encodedPayload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object>{
        'sub': userId,
        'exp': expiresAt,
        'roles': const <String>['ROLE_LISTENER'],
      }),
    ),
  );
  await manager.restore(
    tokenOverride: Future<String?>.value(
      '$encodedHeader.$encodedPayload.test-signature',
    ),
  );
  assert(manager.session.isAuthenticated);
  assert(manager.session.userId == userId);
  serviceLocator.registerSingleton<AuthSessionManager>(
    manager,
    dispose: (value) => value.dispose(),
  );
}

class _NoopTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _NoopAuthSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSessionMetadata?> read() async => null;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
}
