import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/jwt_claims.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';

void main() {
  group('JwtClaims', () {
    final DateTime now = DateTime.utc(2026, 7, 13, 12);

    test(
      'fails closed for malformed tokens and mandatory claim boundaries',
      () {
        expect(JwtClaims.tryParse(null, now: now), isNull);
        expect(JwtClaims.tryParse('', now: now), isNull);
        expect(JwtClaims.tryParse('header.payload', now: now), isNull);
        expect(JwtClaims.tryParse('a.%%%25.c', now: now), isNull);
        expect(
          JwtClaims.tryParse(
            _token(<String, Object?>{'sub': 'user-1'}),
            now: now,
          ),
          isNull,
        );
        expect(
          JwtClaims.tryParse(
            _token(<String, Object?>{'sub': ' ', 'exp': _seconds(now, 120)}),
            now: now,
          ),
          isNull,
        );
        expect(
          JwtClaims.tryParse(
            _token(<String, Object?>{'sub': 'user-1', 'exp': 0}),
            now: now,
          ),
          isNull,
        );
        expect(
          JwtClaims.tryParse(
            _token(<String, Object?>{
              'sub': 'user-1',
              'exp': _seconds(now, 30),
            }),
            now: now,
          ),
          isNull,
          reason: 'The default safety window is inclusive at 30 seconds.',
        );
      },
    );

    test('parses numeric-string expiry and normalizes list claims', () {
      final JwtClaims? claims = JwtClaims.tryParse(
        _token(<String, Object?>{
          'sub': ' user-1 ',
          'exp': _seconds(now, 90).toString(),
          'roles': <Object?>[' ROLE_LISTENER ', '', 7],
          'permissions': ' READ_PROFILE, ,WRITE_PROFILE ',
        }),
        now: now,
      );

      expect(claims, isNotNull);
      expect(claims!.subject, 'user-1');
      expect(claims.expiresAt, now.add(const Duration(seconds: 90)));
      expect(claims.roles, <String>['ROLE_LISTENER', '7']);
      expect(claims.permissions, <String>['READ_PROFILE', 'WRITE_PROFILE']);
      expect(() => claims.roles.add('ROLE_OTHER'), throwsUnsupportedError);
    });

    test('supports authority and singular-role compatibility claims', () {
      final JwtClaims? authorities = JwtClaims.tryParse(
        _token(<String, Object?>{
          'sub': 'user-1',
          'exp': _seconds(now, 120),
          'authorities': 'ROLE_LISTENER,READ_PROFILE',
        }),
        now: now,
      );
      final JwtClaims? role = JwtClaims.tryParse(
        _token(<String, Object?>{
          'sub': 'user-2',
          'exp': _seconds(now, 120),
          'role': 'ROLE_VENUE',
        }),
        now: now,
      );

      expect(authorities?.roles, <String>['ROLE_LISTENER', 'READ_PROFILE']);
      expect(role?.roles, <String>['ROLE_VENUE']);
    });

    test('allows a caller-defined zero safety window', () {
      final String token = _token(<String, Object?>{
        'sub': 'user-1',
        'exp': _seconds(now, 1),
      });

      expect(
        JwtClaims.tryParse(token, now: now, clockSkew: Duration.zero),
        isNotNull,
      );
    });
  });

  group('AuthSession value contract', () {
    test('guest is unauthenticated and has no authorization metadata', () {
      const AuthSession guest = AuthSession.guest();

      expect(guest.isAuthenticated, isFalse);
      expect(guest.isActive, isFalse);
      expect(guest.isPendingVenue, isFalse);
      expect(guest.normalizedRoles, isEmpty);
      expect(guest.hasAnyRole(const <String>['ROLE_LISTENER']), isFalse);
    });

    test('copies authorization lists and compares roles canonically', () {
      final List<String> roles = <String>[' role_listener ', 'ROLE_VENUE'];
      final List<String> permissions = <String>['READ_PROFILE'];
      final AuthSession session = AuthSession.authenticated(
        token: 'token',
        userId: 'user-1',
        username: 'listener',
        accountStatus: ' active ',
        roles: roles,
        permissions: permissions,
        expiresAt: DateTime.utc(2026, 7, 14),
        isAdmin: false,
      );

      roles.add('ROLE_OTHER');
      permissions.clear();

      expect(session.isAuthenticated, isTrue);
      expect(session.isActive, isTrue);
      expect(session.roles, <String>[' role_listener ', 'ROLE_VENUE']);
      expect(session.permissions, <String>['READ_PROFILE']);
      expect(session.normalizedRoles, <String>{'ROLE_LISTENER', 'ROLE_VENUE'});
      expect(session.hasAnyRole(const <String>[' role_venue ']), isTrue);
      expect(() => session.roles.add('ROLE_OTHER'), throwsUnsupportedError);
    });

    test('recognizes pending venue status case-insensitively', () {
      final AuthSession session = AuthSession.authenticated(
        token: 'token',
        userId: 'user-1',
        username: null,
        accountStatus: ' pending_venue_request ',
        roles: const <String>[],
        permissions: const <String>[],
        expiresAt: DateTime.utc(2026, 7, 14),
        isAdmin: false,
      );

      expect(session.isPendingVenue, isTrue);
      expect(session.isActive, isFalse);
    });
  });

  group('AuthSessionMetadata', () {
    test('round-trips persisted UX-only fields with a schema version', () {
      const AuthSessionMetadata metadata = AuthSessionMetadata(
        username: 'display-name',
        accountStatus: 'ACTIVE',
      );

      final Map<String, dynamic> json = metadata.toJson();
      final AuthSessionMetadata restored = AuthSessionMetadata.fromJson(json);

      expect(json['version'], 1);
      expect(restored.username, 'display-name');
      expect(restored.accountStatus, 'ACTIVE');
    });

    test('coerces non-null metadata values to strings', () {
      final AuthSessionMetadata metadata = AuthSessionMetadata.fromJson(
        <String, dynamic>{'username': 42, 'accountStatus': true},
      );

      expect(metadata.username, '42');
      expect(metadata.accountStatus, 'true');
    });
  });

  group('AuthSessionManager edge decisions', () {
    final DateTime now = DateTime.utc(2026, 7, 13, 12);

    test(
      'restores signed identity and infers admin from manage permission',
      () async {
        final _MemoryTokenStore tokenStore = _MemoryTokenStore(
          _token(<String, Object?>{
            'sub': 'jwt-user',
            'exp': _seconds(now, 600),
            'roles': <String>['role_listener'],
            'permissions': <String>['manage_users'],
          }),
        );
        final _MemorySessionStore sessionStore = _MemorySessionStore(
          const AuthSessionMetadata(
            username: 'display-name',
            accountStatus: 'ACTIVE',
          ),
        );
        final AuthSessionManager manager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: sessionStore,
          clock: () => now,
        );
        addTearDown(manager.dispose);

        final AuthSession session = await manager.restore();

        expect(session.userId, 'jwt-user');
        expect(session.username, 'display-name');
        expect(session.isAdmin, isTrue);
        expect(tokenStore.clearCount, 0);
        expect(sessionStore.clearCount, 0);
      },
    );

    test(
      'invalid persisted token fails closed and clears both stores',
      () async {
        final _MemoryTokenStore tokenStore = _MemoryTokenStore('not-a-token');
        final _MemorySessionStore sessionStore = _MemorySessionStore(
          const AuthSessionMetadata(accountStatus: 'ACTIVE'),
        );
        final AuthSessionManager manager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: sessionStore,
          clock: () => now,
        );
        addTearDown(manager.dispose);

        final AuthSession session = await manager.restore();

        expect(session.isAuthenticated, isFalse);
        expect(tokenStore.value, isNull);
        expect(sessionStore.value, isNull);
        expect(tokenStore.clearCount, 1);
        expect(sessionStore.clearCount, 1);
      },
    );

    test('roleless token without status metadata fails closed', () async {
      final _MemoryTokenStore tokenStore = _MemoryTokenStore(
        _token(<String, Object?>{'sub': 'user-1', 'exp': _seconds(now, 600)}),
      );
      final _MemorySessionStore sessionStore = _MemorySessionStore(null);
      final AuthSessionManager manager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
        clock: () => now,
      );
      addTearDown(manager.dispose);

      expect((await manager.restore()).isAuthenticated, isFalse);
      expect(tokenStore.clearCount, 1);
      expect(sessionStore.clearCount, 1);
    });

    test(
      'preview restore does not read or mutate persisted credentials',
      () async {
        final _MemoryTokenStore tokenStore = _MemoryTokenStore(
          'persisted-token',
        );
        final _MemorySessionStore sessionStore = _MemorySessionStore(
          const AuthSessionMetadata(accountStatus: 'ACTIVE'),
        );
        final AuthSessionManager manager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: sessionStore,
          clock: () => now,
        );
        addTearDown(manager.dispose);

        final AuthSession session = await manager.restore(
          tokenOverride: Future<String?>.value('invalid-preview'),
        );

        expect(session.isAuthenticated, isFalse);
        expect(tokenStore.readCount, 0);
        expect(sessionStore.readCount, 0);
        expect(tokenStore.clearCount, 0);
        expect(sessionStore.clearCount, 0);
        expect(tokenStore.value, 'persisted-token');
      },
    );

    test(
      'rejectUnauthorizedToken ignores stale responses but ends current session',
      () async {
        final String token = _token(<String, Object?>{
          'sub': 'user-1',
          'exp': _seconds(now, 600),
          'roles': <String>['ROLE_LISTENER'],
        });
        final _MemoryTokenStore tokenStore = _MemoryTokenStore(token);
        final _MemorySessionStore sessionStore = _MemorySessionStore(
          const AuthSessionMetadata(accountStatus: 'ACTIVE'),
        );
        var endedCount = 0;
        final AuthSessionManager manager = AuthSessionManager(
          tokenStore: tokenStore,
          sessionStore: sessionStore,
          clock: () => now,
          onSessionEnded: () async => endedCount += 1,
        );
        addTearDown(manager.dispose);
        await manager.restore();

        await manager.rejectUnauthorizedToken('older-token');
        expect(manager.session.isAuthenticated, isTrue);
        expect(endedCount, 0);

        await manager.rejectUnauthorizedToken(token);
        expect(manager.session.isAuthenticated, isFalse);
        expect(endedCount, 1);
        expect(tokenStore.value, isNull);
        expect(sessionStore.value, isNull);
      },
    );

    test('invalid start clears prior credentials before throwing', () async {
      final _MemoryTokenStore tokenStore = _MemoryTokenStore('old-token');
      final _MemorySessionStore sessionStore = _MemorySessionStore(
        const AuthSessionMetadata(
          username: 'old-user',
          accountStatus: 'ACTIVE',
        ),
      );
      final AuthSessionManager manager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
        clock: () => now,
      );
      addTearDown(manager.dispose);

      await expectLater(
        manager.startSession(
          token: 'invalid',
          username: 'new-user',
          accountStatus: 'ACTIVE',
        ),
        throwsFormatException,
      );

      expect(manager.session.isAuthenticated, isFalse);
      expect(tokenStore.value, isNull);
      expect(sessionStore.value, isNull);
    });

    test('replacing a session cancels its old expiry timer', () async {
      final _MemoryTokenStore tokenStore = _MemoryTokenStore(null);
      final _MemorySessionStore sessionStore = _MemorySessionStore(null);
      final List<_ManualTimer> timers = <_ManualTimer>[];
      final Completer<void> ended = Completer<void>();
      final AuthSessionManager manager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: sessionStore,
        clock: () => now,
        expiryTimerFactory: (_, callback) {
          final _ManualTimer timer = _ManualTimer(callback);
          timers.add(timer);
          return timer;
        },
        onSessionEnded: () async => ended.complete(),
      );
      addTearDown(manager.dispose);
      final String first = _token(<String, Object?>{
        'sub': 'user-1',
        'exp': _seconds(now, 600),
        'roles': <String>['ROLE_LISTENER'],
      });
      final String second = _token(<String, Object?>{
        'sub': 'user-2',
        'exp': _seconds(now, 900),
        'roles': <String>['ROLE_LISTENER'],
      });

      await manager.startSession(
        token: first,
        username: 'first',
        accountStatus: 'ACTIVE',
      );
      await manager.startSession(
        token: second,
        username: 'second',
        accountStatus: 'ACTIVE',
      );

      expect(timers, hasLength(2));
      expect(timers.first.isActive, isFalse);
      timers.first.fire();
      expect(manager.session.token, second);

      timers.last.fire();
      await ended.future;
      expect(manager.session.isAuthenticated, isFalse);
    });
  });
}

int _seconds(DateTime base, int offsetSeconds) =>
    base.add(Duration(seconds: offsetSeconds)).millisecondsSinceEpoch ~/ 1000;

String _token(Map<String, Object?> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return '${encode(<String, String>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode(payload)}.signature';
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.value);

  String? value;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    value = null;
  }

  @override
  Future<String?> readToken() async {
    readCount += 1;
    return value;
  }

  @override
  Future<void> writeToken(String token) async {
    writeCount += 1;
    value = token;
  }
}

class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.value);

  AuthSessionMetadata? value;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    value = null;
  }

  @override
  Future<AuthSessionMetadata?> read() async {
    readCount += 1;
    return value;
  }

  @override
  Future<void> write(AuthSessionMetadata metadata) async {
    writeCount += 1;
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
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _tick = 1;
    _callback();
  }
}
