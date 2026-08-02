import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/jwt_claims.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';

void main() {
  group('JWT session validation', () {
    final now = DateTime.utc(2026, 7, 13, 8);

    test('accepts a structurally valid token with safe lifetime', () {
      final token = _token(
        subject: 'signed-user-id',
        expiresAt: now.add(const Duration(minutes: 5)),
        roles: const ['ROLE_MUSICIAN'],
      );

      final claims = JwtClaims.tryParse(token, now: now);

      expect(claims?.subject, 'signed-user-id');
      expect(claims?.roles, const ['ROLE_MUSICIAN']);
    });

    test('rejects expired and near-expiry tokens', () {
      expect(
        JwtClaims.tryParse(
          _token(
            subject: 'user',
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
          now: now,
        ),
        isNull,
      );
      expect(
        JwtClaims.tryParse(
          _token(
            subject: 'user',
            expiresAt: now.add(const Duration(seconds: 20)),
          ),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('public API classification', () {
    test('allows only exact POST auth operations', () {
      expect(isPublicApiRequest('POST', '/api/v1/auth/login'), isTrue);
      expect(
        isPublicApiRequest('POST', '/api/v1/auth/forgot-password'),
        isTrue,
      );
      expect(isPublicApiRequest('POST', '/api/v1/auth/reset-password'), isTrue);
      expect(isPublicApiRequest('GET', '/api/v1/auth/login'), isFalse);
      expect(isPublicApiRequest('PUT', '/api/v1/auth/register'), isFalse);
      expect(isPublicApiRequest('PATCH', '/api/v1/users/me/username'), isFalse);
      expect(
        isPublicApiRequest('POST', '/api/v1/auth/complete-google-profile'),
        isFalse,
      );
    });

    test('matches backend public discovery and profile-media routes', () {
      expect(isPublicApiRequest('GET', '/api/v1/events/discover'), isTrue);
      expect(isPublicApiRequest('POST', '/api/v1/events/discover'), isFalse);
      expect(isPublicApiRequest('GET', '/api/v1/venues/abc'), isTrue);
      expect(
        isPublicApiRequest('GET', '/api/v1/profiles/MUSICIAN/profile-id/media'),
        isTrue,
      );
      expect(
        isPublicApiRequest('POST', '/api/v1/user/media/init-upload'),
        isFalse,
      );
    });

    test('allows only the required public Spotify by-ids POST', () {
      expect(
        isPublicApiRequest('POST', '/api/v1/spotify/tracks/by-ids'),
        isTrue,
      );
      expect(
        isPublicApiRequest('DELETE', '/api/v1/spotify/tracks/by-ids'),
        isFalse,
      );
      expect(
        isPublicApiRequest('GET', '/api/v1/spotify/tracks/by-ids'),
        isFalse,
      );
      expect(
        isPublicApiRequest('GET', '/api/v1/spotify/tracks/track-id'),
        isTrue,
      );
    });
  });

  group('AuthSessionManager', () {
    test('derives identity and authorization only from JWT claims', () async {
      final now = DateTime.now().toUtc();
      final token = _token(
        subject: 'jwt-user-id',
        expiresAt: now.add(const Duration(hours: 1)),
        roles: const ['ROLE_LISTENER'],
      );
      final tokenStore = _MemoryTokenStore(token);
      final metadataStore = _MemorySessionStore(
        const AuthSessionMetadata(
          username: 'display-name',
          accountStatus: 'ACTIVE',
        ),
      );
      final manager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: metadataStore,
      );
      addTearDown(manager.dispose);

      final session = await manager.restore();

      expect(session.userId, 'jwt-user-id');
      expect(session.roles, const ['ROLE_LISTENER']);
      expect(session.isAdmin, isFalse);
      expect(session.username, 'display-name');
    });

    test('logout clears credentials and runs realtime cleanup once', () async {
      final tokenStore = _MemoryTokenStore(
        _token(
          subject: 'user',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      final metadataStore = _MemorySessionStore(
        const AuthSessionMetadata(accountStatus: 'ACTIVE'),
      );
      var cleanupCount = 0;
      final manager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: metadataStore,
        onSessionEnded: () async => cleanupCount += 1,
      );
      addTearDown(manager.dispose);
      await manager.restore();

      await Future.wait([manager.logout(), manager.logout()]);

      expect(manager.session.isAuthenticated, isFalse);
      expect(tokenStore.value, isNull);
      expect(metadataStore.value, isNull);
      expect(cleanupCount, 1);
    });

    test(
      'startSession waits for logout cleanup before committing new credentials',
      () async {
        final oldToken = _token(
          subject: 'old-user',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          roles: const ['ROLE_LISTENER'],
        );
        final newToken = _token(
          subject: 'new-user',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          roles: const ['ROLE_LISTENER'],
        );
        final tokenStore = _BlockingClearTokenStore(oldToken);
        final metadataStore = _MemorySessionStore(
          const AuthSessionMetadata(
            username: 'old-user',
            accountStatus: 'ACTIVE',
          ),
        );
        final manager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: metadataStore,
        );
        addTearDown(manager.dispose);
        await manager.restore();

        final logoutFuture = manager.logout();
        await tokenStore.clearStarted.future;
        final startFuture = manager.startSession(
          token: newToken,
          username: 'new-user',
          accountStatus: 'ACTIVE',
        );

        // Give an incorrectly unguarded startSession a chance to overwrite the
        // stores while the old session cleanup is deliberately paused.
        await Future<void>.delayed(Duration.zero);
        final writesBeforeCleanupCompleted = tokenStore.writeCalls;
        final metadataBeforeCleanupCompleted = metadataStore.value;

        tokenStore.allowClear.complete();
        await Future.wait<void>([logoutFuture, startFuture]);

        expect(writesBeforeCleanupCompleted, 0);
        expect(metadataBeforeCleanupCompleted?.username, 'old-user');
        expect(tokenStore.value, newToken);
        expect(metadataStore.value?.username, 'new-user');
        expect(metadataStore.value?.accountStatus, 'ACTIVE');
        expect(manager.session.userId, 'new-user');
        expect(manager.session.isAuthenticated, isTrue);
      },
    );

    test('logout becomes guest even when credential stores fail', () async {
      final manager = AuthSessionManager(
        tokenStore: _FailingTokenStore(
          _token(
            subject: 'user',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
        ),
        sessionStore: _FailingSessionStore(
          const AuthSessionMetadata(accountStatus: 'ACTIVE'),
        ),
      );
      addTearDown(manager.dispose);
      await manager.restore();

      await manager.logout();

      expect(manager.session.isAuthenticated, isFalse);
    });

    test(
      'failed token commit attempts to clear both credential stores',
      () async {
        final tokenStore = _FailingTokenStore('old-token', failWrite: true);
        final metadataStore = _MemorySessionStore(
          const AuthSessionMetadata(
            username: 'old-user',
            accountStatus: 'ACTIVE',
          ),
        );
        final manager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: metadataStore,
        );
        addTearDown(manager.dispose);

        await expectLater(
          manager.startSession(
            token: _token(
              subject: 'new-user',
              expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              roles: const ['ROLE_LISTENER'],
            ),
            username: 'new-user',
            accountStatus: 'ACTIVE',
          ),
          throwsA(isA<StateError>()),
        );

        expect(tokenStore.clearCalls, 1);
        expect(metadataStore.value, isNull);
        expect(manager.session.isAuthenticated, isFalse);
      },
    );

    test('terminates a live session when its runtime expiry fires', () async {
      final now = DateTime.utc(2026, 7, 13, 12);
      final tokenStore = _MemoryTokenStore(
        _token(
          subject: 'expiring-user',
          expiresAt: now.add(const Duration(minutes: 2)),
          roles: const ['ROLE_LISTENER'],
        ),
      );
      final metadataStore = _MemorySessionStore(
        const AuthSessionMetadata(accountStatus: 'ACTIVE'),
      );
      late _ManualTimer timer;
      Duration? scheduledDelay;
      final cleanupDone = Completer<void>();
      final manager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: metadataStore,
        clock: () => now,
        expiryTimerFactory: (duration, callback) {
          scheduledDelay = duration;
          return timer = _ManualTimer(callback);
        },
        onSessionEnded: () async => cleanupDone.complete(),
      );
      addTearDown(manager.dispose);

      await manager.restore();
      expect(manager.session.isAuthenticated, isTrue);
      expect(scheduledDelay, const Duration(seconds: 90));

      timer.fire();
      await cleanupDone.future;

      expect(manager.session.isAuthenticated, isFalse);
      expect(tokenStore.value, isNull);
      expect(metadataStore.value, isNull);
    });
  });

  group('AppRouteGuard', () {
    test('requires authentication and isolates admin route', () {
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.notifications,
          const AuthSession.guest(),
        ),
        AppRoutes.login,
      );

      final listener = _session(roles: const ['ROLE_LISTENER']);
      expect(
        AppRouteGuard.redirectFor(AppRoutes.adminDashboard, listener),
        AppRoutes.listenerProfile,
      );
    });

    test('allows guest venue pending but redirects active accounts', () {
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.venuePending,
          const AuthSession.guest(),
        ),
        isNull,
      );

      final listener = _session(roles: const ['ROLE_LISTENER']);
      expect(
        AppRouteGuard.redirectFor(AppRoutes.venuePending, listener),
        AppRoutes.listenerProfile,
      );
    });

    test('isolates pending venue and unsupported owner routes', () {
      final pending = _session(
        roles: const [],
        accountStatus: 'PENDING_VENUE_REQUEST',
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.home, pending),
        AppRoutes.venuePending,
      );

      final producer = _session(roles: const ['ROLE_PRODUCER']);
      expect(
        AppRouteGuard.redirectFor(AppRoutes.musicianProfile, producer),
        AppRoutes.home,
      );
    });

    test('allows an admin session into admin route', () {
      final admin = _session(roles: const ['ROLE_ADMIN'], isAdmin: true);
      expect(
        AppRouteGuard.redirectFor(AppRoutes.adminDashboard, admin),
        isNull,
      );
    });

    test('fails closed for an authenticated session without a role', () {
      final rolesPending = _session(roles: const []);

      expect(AppRouteGuard.startRouteFor(rolesPending), AppRoutes.login);
    });

    test('prefers backstage for listener accounts with a backstage role', () {
      final multiRole = _session(
        roles: const ['ROLE_LISTENER', 'ROLE_MUSICIAN'],
      );

      expect(AppRouteGuard.startRouteFor(multiRole), AppRoutes.home);
    });
  });
}

AuthSession _session({
  required List<String> roles,
  String accountStatus = 'ACTIVE',
  bool isAdmin = false,
}) {
  return AuthSession.authenticated(
    token: 'test-token',
    userId: 'user-id',
    username: 'user',
    accountStatus: accountStatus,
    roles: roles,
    permissions: const [],
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    isAdmin: isAdmin,
  );
}

String _token({
  required String subject,
  required DateTime expiresAt,
  List<String> roles = const [],
  List<String> permissions = const [],
}) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const {'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': subject, 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000, 'roles': roles, 'permissions': permissions})}.signature';
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.value);

  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async => value = token;
}

class _BlockingClearTokenStore implements TokenStore {
  _BlockingClearTokenStore(this.value);

  String? value;
  final Completer<void> clearStarted = Completer<void>();
  final Completer<void> allowClear = Completer<void>();
  int writeCalls = 0;

  @override
  Future<void> clear() async {
    if (!clearStarted.isCompleted) clearStarted.complete();
    await allowClear.future;
    value = null;
  }

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async {
    writeCalls += 1;
    value = token;
  }
}

class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.value);

  AuthSessionMetadata? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthSessionMetadata?> read() async => value;

  @override
  Future<void> write(AuthSessionMetadata metadata) async => value = metadata;
}

class _FailingTokenStore implements TokenStore {
  _FailingTokenStore(this.value, {this.failWrite = false});

  String? value;
  final bool failWrite;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    throw StateError('secure token storage unavailable');
  }

  @override
  Future<String?> readToken() async => value;

  @override
  Future<void> writeToken(String token) async {
    if (failWrite) throw StateError('secure token storage unavailable');
    value = token;
  }
}

class _FailingSessionStore implements AuthSessionStore {
  _FailingSessionStore(this.value);

  AuthSessionMetadata? value;

  @override
  Future<void> clear() async {
    throw StateError('secure metadata storage unavailable');
  }

  @override
  Future<AuthSessionMetadata?> read() async => value;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {
    value = metadata;
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function() _callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) return;
    _active = false;
    _tick = 1;
    _callback();
  }
}
