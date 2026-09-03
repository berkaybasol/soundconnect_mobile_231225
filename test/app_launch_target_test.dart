import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';

void main() {
  group('resolveLaunchTarget', () {
    test('returns guest when token is null or blank', () {
      expect(resolveLaunchTarget(null), AppLaunchTarget.guest);
      expect(resolveLaunchTarget(''), AppLaunchTarget.guest);
      expect(resolveLaunchTarget('   '), AppLaunchTarget.guest);
    });

    test('returns guest when token is malformed', () {
      expect(resolveLaunchTarget('token'), AppLaunchTarget.guest);
      expect(resolveLaunchTarget(' token '), AppLaunchTarget.guest);
    });

    test('returns home only for a non-expiring JWT-shaped token', () {
      final now = DateTime.utc(2026, 7, 13, 8);
      expect(
        resolveLaunchTarget(
          _token(now.add(const Duration(minutes: 5))),
          now: now,
        ),
        AppLaunchTarget.home,
      );
      expect(
        resolveLaunchTarget(
          _token(now.add(const Duration(seconds: 10))),
          now: now,
        ),
        AppLaunchTarget.guest,
      );
    });
  });

  group('resolveSessionLaunchTarget', () {
    test(
      'restores pending and rejected Studio sessions to their own screens',
      () {
        expect(
          resolveSessionLaunchTarget(
            _session(accountStatus: 'PENDING_STUDIO_REQUEST'),
          ),
          AppLaunchTarget.studioPending,
        );
        expect(
          resolveSessionLaunchTarget(
            _session(accountStatus: 'REJECTED_STUDIO_REQUEST'),
          ),
          AppLaunchTarget.studioRejected,
        );
      },
    );

    test('restores an unfinished listener choice to the chooser', () {
      final session = AuthSession.authenticated(
        token: 'token',
        userId: 'listener-user',
        username: 'listener',
        accountStatus: 'ACTIVE',
        roles: const <String>['ROLE_LISTENER'],
        permissions: const <String>[],
        expiresAt: DateTime.utc(2030),
        isAdmin: false,
        requiresListenerProfileChoice: true,
      );

      expect(
        resolveSessionLaunchTarget(session),
        AppLaunchTarget.listenerProfileChoice,
      );
      expect(shouldStartAuthenticatedSessionServices(session), isFalse);
      expect(
        resolveSessionChangeNavigationRoute(
          wasAuthenticated: true,
          wasListenerChoiceRequired: false,
          current: session,
        ),
        '/listener-profile-choice',
      );
    });

    test('starts session services after the listener choice is complete', () {
      final session = AuthSession.authenticated(
        token: 'token',
        userId: 'listener-user',
        username: 'listener',
        accountStatus: 'ACTIVE',
        roles: const <String>['ROLE_LISTENER'],
        permissions: const <String>[],
        expiresAt: DateTime.utc(2030),
        isAdmin: false,
      );

      expect(shouldStartAuthenticatedSessionServices(session), isTrue);
    });
  });
}

AuthSession _session({required String accountStatus}) =>
    AuthSession.authenticated(
      token: 'token',
      userId: 'studio-user',
      username: 'studio',
      accountStatus: accountStatus,
      roles: const [],
      permissions: const [],
      expiresAt: DateTime.utc(2030),
      isAdmin: false,
    );

String _token(DateTime expiresAt) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const {'alg': 'HS256'})}.'
      '${encode({'sub': 'user-id', 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.signature';
}
