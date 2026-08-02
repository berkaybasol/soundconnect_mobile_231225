import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';

void main() {
  test('pending studio account is confined to its review screen', () {
    final session = AuthSession.authenticated(
      token: 'token',
      userId: 'user-1',
      username: 'studio-owner',
      accountStatus: 'PENDING_STUDIO_REQUEST',
      roles: const [],
      permissions: const [],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      isAdmin: false,
    );

    expect(
      AppRouteGuard.redirectFor(AppRoutes.studioProfile, session),
      AppRoutes.studioPending,
    );
    expect(AppRouteGuard.redirectFor(AppRoutes.studioPending, session), isNull);
    expect(AppRouteGuard.startRouteFor(session), AppRoutes.studioPending);
  });
}
