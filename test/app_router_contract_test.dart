import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_pending_screen.dart';

void main() {
  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('real router lets the guest OTP flow reach venue pending', (
    tester,
  ) async {
    _registerSession(const AuthSession.guest());
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.shrink(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    navigatorKey.currentState!.pushNamed<void>(AppRoutes.venuePending);
    await tester.pumpAndSettle();

    expect(find.byType(VenuePendingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      AppRouteGuard.redirectFor(
        AppRoutes.venuePending,
        const AuthSession.guest(),
      ),
      isNull,
    );
  });

  test('real router redirects an active user away from venue pending', () {
    final session = AuthSession.authenticated(
      token: 'test-token',
      userId: 'listener-id',
      username: 'listener',
      accountStatus: 'ACTIVE',
      roles: const <String>['ROLE_LISTENER'],
      permissions: const <String>[],
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      isAdmin: false,
    );
    _registerSession(session);

    final route = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.venuePending),
    );

    expect(route.settings.name, AppRoutes.listenerProfile);
    expect(
      AppRouteGuard.redirectFor(AppRoutes.venuePending, session),
      AppRoutes.listenerProfile,
    );
  });

  test('password reset is anonymous and settings routes are protected', () {
    const guest = AuthSession.guest();
    expect(AppRouteGuard.redirectFor(AppRoutes.forgotPassword, guest), isNull);
    expect(
      AppRouteGuard.redirectFor(AppRoutes.settings, guest),
      AppRoutes.login,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.accountSettings, guest),
      AppRoutes.login,
    );

    final activeSession = AuthSession.authenticated(
      token: 'test-token',
      userId: 'listener-id',
      username: 'listener',
      accountStatus: 'ACTIVE',
      roles: const <String>['ROLE_LISTENER'],
      permissions: const <String>[],
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      isAdmin: false,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.settings, activeSession),
      isNull,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.accountSettings, activeSession),
      isNull,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.forgotPassword, activeSession),
      AppRoutes.listenerProfile,
    );

    final adminSession = AuthSession.authenticated(
      token: 'admin-token',
      userId: 'admin-id',
      username: 'owner',
      accountStatus: 'ACTIVE',
      roles: const <String>['ROLE_OWNER'],
      permissions: const <String>['ADMIN_PANEL_ACCESS'],
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      isAdmin: true,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.accountSettings, adminSession),
      isNull,
    );
  });
}

void _registerSession(AuthSession session) {
  GetIt.instance.registerSingleton<AuthSessionManager>(
    _FixedAuthSessionManager(session),
    dispose: (manager) => manager.dispose(),
  );
}

class _FixedAuthSessionManager extends AuthSessionManager {
  _FixedAuthSessionManager(this._fixedSession)
    : super(tokenStore: _NoopTokenStore(), sessionStore: _NoopSessionStore());

  final AuthSession _fixedSession;

  @override
  AuthSession get session => _fixedSession;
}

class _NoopTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _NoopSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSessionMetadata?> read() async => null;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
}
