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
import 'package:soundconnect_23_12_25codx/core/policy/access_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_pending_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';

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

  testWidgets('real router exposes the rejected Studio support screen', (
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
    navigatorKey.currentState!.pushNamed<void>(AppRoutes.studioRejected);
    await tester.pumpAndSettle();

    expect(find.byType(VenuePendingScreen), findsOneWidget);
    expect(find.text('Stüdyo başvurun sonuçlandı'), findsOneWidget);
    expect(find.textContaining('karara itiraz etmek'), findsOneWidget);
    expect(
      AppRouteGuard.redirectFor(
        AppRoutes.studioRejected,
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

  test(
    'listener profile choice is mandatory only while selection is pending',
    () {
      const guest = AuthSession.guest();
      final musician = _activeSession(const <String>['ROLE_MUSICIAN']);
      final listener = _activeSession(const <String>['ROLE_LISTENER']);
      final pendingListener = _activeSession(const <String>[
        'ROLE_LISTENER',
      ], requiresListenerProfileChoice: true);

      expect(
        AppRouteGuard.redirectFor(AppRoutes.listenerProfileChoice, guest),
        AppRoutes.login,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.listenerProfileChoice, musician),
        AppRoutes.home,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.listenerProfileChoice, listener),
        AppRoutes.listenerProfile,
      );
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.listenerProfileChoice,
          pendingListener,
        ),
        isNull,
      );
      expect(
        AppRouteGuard.redirectFor(AppRoutes.listenerProfile, pendingListener),
        AppRoutes.listenerProfileChoice,
      );
      expect(
        AppRouteGuard.startRouteFor(pendingListener),
        AppRoutes.listenerProfileChoice,
      );
    },
  );

  test('listener public profile requires auth and a non-empty profile id', () {
    const guest = AuthSession.guest();
    expect(
      AppRouteGuard.redirectFor(AppRoutes.listenerPublicProfile, guest),
      AppRoutes.login,
    );

    final listener = _activeSession(const <String>['ROLE_LISTENER']);
    expect(
      AppRouteGuard.redirectFor(AppRoutes.listenerPublicProfile, listener),
      isNull,
    );
    _registerSession(listener);

    final validRoute = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.listenerPublicProfile,
        arguments: PublicProfileArgs(profileId: 'listener-profile-id'),
      ),
    );
    final invalidRoute = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.listenerPublicProfile,
        arguments: PublicProfileArgs(profileId: '   '),
      ),
    );

    expect(validRoute.settings.name, AppRoutes.listenerPublicProfile);
    expect(invalidRoute.settings.name, AppRoutes.listenerProfile);
  });

  test(
    'table creation denies Venue and Studio roles but keeps personal roles',
    () {
      for (final roles in <List<String>>[
        const <String>['ROLE_VENUE'],
        const <String>[' studio '],
        const <String>['ROLE_MUSICIAN', 'VENUE'],
        const <String>['ROLE_LISTENER', 'ROLE_STUDIO'],
      ]) {
        final session = _activeSession(roles);
        expect(AccessPolicy.canCreateOrJoinTableGroups(roles), isFalse);
        expect(
          AppRouteGuard.redirectFor(AppRoutes.tableGroupCreate, session),
          AppRoutes.tableGroupList,
        );
        expect(
          AppRouteGuard.redirectFor(AppRoutes.tableGroupList, session),
          isNull,
        );
      }

      for (final roles in <List<String>>[
        const <String>['ROLE_MUSICIAN'],
        const <String>['LISTENER'],
        const <String>['ROLE_PRODUCER'],
      ]) {
        final session = _activeSession(roles);
        expect(AccessPolicy.canCreateOrJoinTableGroups(roles), isTrue);
        expect(
          AppRouteGuard.redirectFor(AppRoutes.tableGroupCreate, session),
          isNull,
        );
      }
    },
  );

  test('Studio owner calendar rejects invalid args and non-Studio roles', () {
    final listener = AuthSession.authenticated(
      token: 'test-token',
      userId: 'listener-id',
      username: 'listener',
      accountStatus: 'ACTIVE',
      roles: const <String>['ROLE_LISTENER'],
      permissions: const <String>[],
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      isAdmin: false,
    );
    _registerSession(listener);

    final invalidArgsRoute = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.studioReservationCalendar),
    );
    final unauthorizedOwnerRoute = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.studioReservationCalendar,
        arguments: StudioReservationCalendarArgs(
          roomId: 'room-1',
          studioProfileId: 'studio-1',
          ownerMode: true,
        ),
      ),
    );
    final customerRoute = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.studioReservationCalendar,
        arguments: StudioReservationCalendarArgs(
          roomId: 'room-1',
          studioProfileId: 'studio-1',
          ownerMode: false,
        ),
      ),
    );

    expect(invalidArgsRoute.settings.name, AppRoutes.listenerProfile);
    expect(unauthorizedOwnerRoute.settings.name, AppRoutes.listenerProfile);
    expect(customerRoute.settings.name, AppRoutes.studioReservationCalendar);
    expect(
      AppRouteGuard.canOpenStudioOwnerReservationCalendar(listener),
      isFalse,
    );
  });

  test('Collab is available only to supported business profile roles', () {
    final listener = AuthSession.authenticated(
      token: 'listener-token',
      userId: 'listener-id',
      username: 'listener',
      accountStatus: 'ACTIVE',
      roles: const <String>['ROLE_LISTENER'],
      permissions: const <String>[],
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      isAdmin: false,
    );
    final musician = AuthSession.authenticated(
      token: 'musician-token',
      userId: 'musician-id',
      username: 'musician',
      accountStatus: 'ACTIVE',
      roles: const <String>['ROLE_MUSICIAN'],
      permissions: const <String>[],
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      isAdmin: false,
    );
    final bareBackstageSessions = <AuthSession>[
      AuthSession.authenticated(
        token: 'bare-musician-token',
        userId: 'bare-musician-id',
        username: 'bare-musician',
        accountStatus: 'ACTIVE',
        roles: const <String>['MUSICIAN'],
        permissions: const <String>[],
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        isAdmin: false,
      ),
      AuthSession.authenticated(
        token: 'bare-venue-token',
        userId: 'bare-venue-id',
        username: 'bare-venue',
        accountStatus: 'ACTIVE',
        roles: const <String>['VENUE'],
        permissions: const <String>[],
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        isAdmin: false,
      ),
      AuthSession.authenticated(
        token: 'bare-studio-token',
        userId: 'bare-studio-id',
        username: 'bare-studio',
        accountStatus: 'ACTIVE',
        roles: const <String>['STUDIO'],
        permissions: const <String>[],
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        isAdmin: false,
      ),
    ];

    final unsupportedBackstageSessions = <AuthSession>[
      AuthSession.authenticated(
        token: 'producer-token',
        userId: 'producer-id',
        username: 'producer',
        accountStatus: 'ACTIVE',
        roles: const <String>['ROLE_PRODUCER'],
        permissions: const <String>[],
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        isAdmin: false,
      ),
      AuthSession.authenticated(
        token: 'organizer-token',
        userId: 'organizer-id',
        username: 'organizer',
        accountStatus: 'ACTIVE',
        roles: const <String>['ORGANIZER'],
        permissions: const <String>[],
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        isAdmin: false,
      ),
    ];

    expect(
      AppRouteGuard.redirectFor(AppRoutes.collabDiscovery, listener),
      AppRoutes.listenerProfile,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.collabDiscovery, musician),
      isNull,
    );
    for (final session in bareBackstageSessions) {
      expect(
        AppRouteGuard.redirectFor(AppRoutes.collabDiscovery, session),
        isNull,
      );
    }
    for (final session in unsupportedBackstageSessions) {
      expect(
        AppRouteGuard.redirectFor(AppRoutes.collabDiscovery, session),
        AppRoutes.home,
      );
    }
  });
}

AuthSession _activeSession(
  List<String> roles, {
  bool requiresListenerProfileChoice = false,
}) {
  return AuthSession.authenticated(
    token: 'table-group-token',
    userId: 'table-group-user',
    username: 'table-group-user',
    accountStatus: 'ACTIVE',
    roles: roles,
    permissions: const <String>[],
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    isAdmin: false,
    requiresListenerProfileChoice: requiresListenerProfileChoice,
  );
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
