import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';

void main() {
  for (final kind in ['VENUE', 'STUDIO']) {
    test('$kind approval resets to own profile only for the same account', () {
      AuthSession owner(String id, String status, List<String> roles) =>
          AuthSession.authenticated(
            token: status,
            userId: id,
            username: 'owner',
            accountStatus: status,
            roles: roles,
            permissions: const [],
            expiresAt: DateTime.utc(2030),
            isAdmin: false,
          );
      final pending = owner('one', 'PENDING_${kind}_REQUEST', []);
      final active = owner('one', 'ACTIVE', ['ROLE_$kind']);
      final expected = kind == 'VENUE'
          ? AppRoutes.venueProfile
          : AppRoutes.studioProfile;
      expect(resolveMembershipApprovalRoute(pending, active), expected);
      expect(
        resolveSessionChangeNavigationRoute(
          wasAuthenticated: true,
          wasListenerChoiceRequired: false,
          previousSession: pending,
          previousUserId: 'one',
          previousToken: pending.token,
          current: active,
        ),
        expected,
      );
      expect(
        resolveMembershipApprovalRoute(
          pending,
          owner('two', 'ACTIVE', ['ROLE_$kind']),
        ),
        isNull,
      );
      expect(
        resolveMembershipApprovalRoute(
          pending,
          owner('one', 'ACTIVE', ['ROLE_LISTENER']),
        ),
        isNull,
      );
      expect(resolveMembershipApprovalRoute(active, active), isNull);
      expect(resolveMembershipApprovalRoute(pending, pending), isNull);
      expect(
        resolveMembershipApprovalRoute(pending, const AuthSession.guest()),
        isNull,
      );
    });
  }
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
