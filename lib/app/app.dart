import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/auth_session.dart';
import '../core/auth/auth_session_manager.dart';
import '../core/auth/jwt_claims.dart';
import '../core/di/service_locator.dart';
import '../modules/admin/presentation/screens/admin_dashboard_screen.dart';
import '../modules/auth/presentation/screens/login_screen.dart';
import '../modules/auth/presentation/screens/venue_pending_screen.dart';
import '../modules/auth/presentation/cubit/auth_cubit.dart';
import '../modules/event/presentation/screens/guest_event_home_screen.dart';
import '../modules/profile/presentation/screens/backstage_profiles_home_screen.dart';
import '../modules/profile/presentation/screens/listener_profile_screen.dart';
import '../modules/profile/domain/profile_media_upload_repository.dart';
import '../modules/location/presentation/cubit/location_cubit.dart';
import '../modules/notification/presentation/cubit/notification_cubit.dart';
import '../shared/theme/theme_controller.dart';
import 'router/app_route_guard.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

enum AppLaunchTarget {
  guest,
  login,
  home,
  listener,
  admin,
  venuePending,
  studioPending,
  studioRejected,
}

AppLaunchTarget resolveLaunchTarget(String? token, {DateTime? now}) {
  return JwtClaims.tryParse(token, now: now) == null
      ? AppLaunchTarget.guest
      : AppLaunchTarget.home;
}

AppLaunchTarget resolveSessionLaunchTarget(AuthSession session) {
  if (!session.isAuthenticated) return AppLaunchTarget.guest;
  return switch (AppRouteGuard.startRouteFor(session)) {
    AppRoutes.venuePending => AppLaunchTarget.venuePending,
    AppRoutes.studioPending => AppLaunchTarget.studioPending,
    AppRoutes.studioRejected => AppLaunchTarget.studioRejected,
    AppRoutes.adminDashboard => AppLaunchTarget.admin,
    AppRoutes.listenerProfile => AppLaunchTarget.listener,
    AppRoutes.home => AppLaunchTarget.home,
    _ => AppLaunchTarget.login,
  };
}

class SoundConnectApp extends StatefulWidget {
  final Future<String?>? initialTokenFuture;
  final ThemeController? themeController;

  const SoundConnectApp({
    super.key,
    this.initialTokenFuture,
    this.themeController,
  });

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final Future<AuthSession> _initialSessionFuture;
  late final ThemeController _themeController;
  late final AuthSessionManager _sessionManager;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _themeController =
        widget.themeController ??
        (serviceLocator.isRegistered<ThemeController>()
            ? serviceLocator<ThemeController>()
            : ThemeController.memory());
    _sessionManager = serviceLocator<AuthSessionManager>();
    _sessionManager.addListener(_onSessionChanged);
    _initialSessionFuture = _sessionManager.restore(
      tokenOverride: widget.initialTokenFuture,
    );
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final isAuthenticated = _sessionManager.session.isAuthenticated;
    final shouldReturnToLogin = _wasAuthenticated && !isAuthenticated;
    _wasAuthenticated = isAuthenticated;
    if (!shouldReturnToLogin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession>(
      future: _initialSessionFuture,
      builder: (context, snapshot) {
        final session = snapshot.data ?? const AuthSession.guest();
        final launchTarget = resolveSessionLaunchTarget(session);
        final waitingForToken =
            snapshot.connectionState == ConnectionState.waiting;

        return MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>(create: (_) => serviceLocator<AuthCubit>()),
            BlocProvider<LocationCubit>(
              create: (_) => serviceLocator<LocationCubit>(),
            ),
            BlocProvider<NotificationCubit>.value(
              value: serviceLocator<NotificationCubit>(),
            ),
          ],
          child: _NotificationBootstrap(
            child: AnimatedBuilder(
              animation: _themeController,
              builder: (_, __) => MaterialApp(
                navigatorKey: _navigatorKey,
                title: 'SoundConnect',
                theme: _themeController.lightTheme,
                darkTheme: _themeController.darkTheme,
                themeMode: _themeController.themeMode,
                onGenerateRoute: AppRouter.onGenerateRoute,
                home: waitingForToken
                    ? _LaunchLoadingScreen()
                    : switch (launchTarget) {
                        AppLaunchTarget.home =>
                          const BackstageProfilesHomeScreen(),
                        AppLaunchTarget.listener => ListenerProfileScreen(),
                        AppLaunchTarget.admin => const AdminDashboardScreen(),
                        AppLaunchTarget.venuePending => VenuePendingScreen(),
                        AppLaunchTarget.studioPending => VenuePendingScreen(
                          membershipType: PendingMembershipType.studio,
                        ),
                        AppLaunchTarget.studioRejected => VenuePendingScreen(
                          membershipType: PendingMembershipType.studioRejected,
                        ),
                        AppLaunchTarget.login => LoginScreen(),
                        AppLaunchTarget.guest => GuestEventHomeScreen(),
                      },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBootstrap extends StatefulWidget {
  final Widget child;

  const _NotificationBootstrap({required this.child});

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap> {
  late final AuthSessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _sessionManager = serviceLocator<AuthSessionManager>();
    _sessionManager.addListener(_syncNotifications);
    unawaited(_syncNotifications());
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_syncNotifications);
    super.dispose();
  }

  Future<void> _syncNotifications() async {
    final cubit = serviceLocator<NotificationCubit>();
    if (_sessionManager.session.isActive) {
      await cubit.ensureStarted();
      unawaited(
        serviceLocator<ProfileMediaUploadRepository>().resumePendingUploads(),
      );
    } else {
      await cubit.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _LaunchLoadingScreen extends StatelessWidget {
  const _LaunchLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
