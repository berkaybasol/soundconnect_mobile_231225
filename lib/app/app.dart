import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/auth_session.dart';
import '../core/auth/auth_session_manager.dart';
import '../core/auth/jwt_claims.dart';
import '../core/deep_link/app_deep_link.dart';
import '../core/deep_link/app_deep_link_policy.dart';
import '../core/deep_link/pending_app_deep_link_store.dart';
import '../core/diagnostics/app_diagnostics.dart';
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
import '../modules/collab/presentation/collab_route_args.dart';
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
  final AppLinkSource? appLinkSource;
  final AppDeepLinkInbox? appDeepLinkInbox;

  const SoundConnectApp({
    super.key,
    this.initialTokenFuture,
    this.themeController,
    this.appLinkSource,
    this.appDeepLinkInbox,
  });

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final Future<AuthSession> _initialSessionFuture;
  late final ThemeController _themeController;
  late final AuthSessionManager _sessionManager;
  late final AppDeepLinkInbox _appDeepLinkInbox;
  late final _CurrentRouteObserver _routeObserver;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _appLinkSubscription;
  bool _wasAuthenticated = false;
  bool _sessionRestoreCompleted = false;
  bool _processingPendingLink = false;
  bool _processPendingLinkAgain = false;
  bool _pendingLinkFrameScheduled = false;
  String? _lastAccessNoticeIdentity;

  @override
  void initState() {
    super.initState();
    _themeController =
        widget.themeController ??
        (serviceLocator.isRegistered<ThemeController>()
            ? serviceLocator<ThemeController>()
            : ThemeController.memory());
    _sessionManager = serviceLocator<AuthSessionManager>();
    _appDeepLinkInbox =
        widget.appDeepLinkInbox ?? serviceLocator<AppDeepLinkInbox>();
    _routeObserver = _CurrentRouteObserver(_schedulePendingLinkProcessing);
    _sessionManager.addListener(_onSessionChanged);
    _initialSessionFuture = _sessionManager.restore(
      tokenOverride: widget.initialTokenFuture,
    );
    final appLinkSource = widget.appLinkSource;
    if (appLinkSource != null) {
      _appLinkSubscription = appLinkSource.uriLinkStream.listen(
        _onIncomingAppLink,
        onError: (Object error, StackTrace stackTrace) {
          AppDiagnostics.reportRecoverable(
            source: 'app-link-stream',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
      unawaited(
        _initialSessionFuture.then((_) {
          if (!mounted) return;
          _sessionRestoreCompleted = true;
          _schedulePendingLinkProcessing();
        }),
      );
    }
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_onSessionChanged);
    unawaited(_appLinkSubscription?.cancel());
    super.dispose();
  }

  Future<void> _onIncomingAppLink(Uri uri) async {
    final target = AppDeepLinkParser.parse(uri);
    if (target == null) return;
    final recorded = await _appDeepLinkInbox.record(target);
    if (recorded == null) return;
    if (!mounted || !_sessionRestoreCompleted) return;
    _schedulePendingLinkProcessing();
  }

  void _schedulePendingLinkProcessing() {
    if (_pendingLinkFrameScheduled || !mounted) return;
    _pendingLinkFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingLinkFrameScheduled = false;
      if (!mounted) return;
      unawaited(_processPendingAppLink());
    });
  }

  Future<void> _processPendingAppLink() async {
    if (!_sessionRestoreCompleted) return;
    if (_processingPendingLink) {
      _processPendingLinkAgain = true;
      return;
    }
    _processingPendingLink = true;
    try {
      do {
        _processPendingLinkAgain = false;
        await _processPendingAppLinkOnce();
      } while (_processPendingLinkAgain && mounted);
    } finally {
      _processingPendingLink = false;
    }
  }

  Future<void> _processPendingAppLinkOnce() async {
    final pending = await _appDeepLinkInbox.pending();
    if (!mounted || pending == null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _schedulePendingLinkProcessing();
      return;
    }

    final session = _sessionManager.session;
    final access = resolveAppDeepLinkAccess(session);
    if (access == AppDeepLinkAccess.requestAuthentication) {
      if (AppRouteGuard.isAnonymousFlowRoute(_routeObserver.currentRouteName)) {
        return;
      }
      navigator.pushNamedAndRemoveUntil<void>(
        AppRoutes.login,
        (route) => false,
        arguments: const LoginRouteArgs(
          initialNotice:
              'İlan detayını görüntülemek için giriş yap veya ücretsiz üye ol.',
        ),
      );
      return;
    }

    // Login owns the post-authentication handoff. Route changes trigger a
    // fresh processing pass, so a warm link arriving during login is retained.
    if (_routeObserver.currentRouteName == AppRoutes.login) return;

    final claim = await _appDeepLinkInbox.claim();
    if (claim.status != AppDeepLinkClaimStatus.acquired) return;
    final claimed = claim.link!;
    if (!mounted) {
      await _appDeepLinkInbox.release(claimed);
      return;
    }

    try {
      if (access == AppDeepLinkAccess.unavailable) {
        if (_lastAccessNoticeIdentity != claimed.identity) {
          _lastAccessNoticeIdentity = claimed.identity;
          _messengerKey.currentState
            ?..removeCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Bu ilanı müzisyen, mekan veya stüdyo hesabıyla görüntüleyebilirsin.',
                ),
              ),
            );
        }
        await _appDeepLinkInbox.complete(claimed);
        return;
      }

      navigator.pushNamed<void>(
        AppRoutes.collabDiscovery,
        arguments: CollabDiscoveryRouteArgs(
          initialListingId: claimed.target.listingId,
        ),
      );
      await _appDeepLinkInbox.complete(claimed);
    } catch (error, stackTrace) {
      await _appDeepLinkInbox.release(claimed);
      AppDiagnostics.reportRecoverable(
        source: 'app-link-navigation',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
                scaffoldMessengerKey: _messengerKey,
                navigatorObservers: <NavigatorObserver>[_routeObserver],
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

class _CurrentRouteObserver extends NavigatorObserver {
  _CurrentRouteObserver(this._onChanged);

  final VoidCallback _onChanged;
  Route<dynamic>? _currentRoute;

  String? get currentRouteName => _currentRoute?.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) _currentRoute = route;
    _onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic> && previousRoute is PageRoute<dynamic>) {
      _currentRoute = previousRoute;
    }
    _onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(_currentRoute, route)) _currentRoute = previousRoute;
    _onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute<dynamic> &&
        (_currentRoute == null || identical(_currentRoute, oldRoute))) {
      _currentRoute = newRoute;
    }
    _onChanged();
  }
}

class _NotificationBootstrap extends StatefulWidget {
  final Widget child;

  const _NotificationBootstrap({required this.child});

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap>
    with WidgetsBindingObserver {
  late final AuthSessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _sessionManager = serviceLocator<AuthSessionManager>();
    WidgetsBinding.instance.addObserver(this);
    _sessionManager.addListener(_syncNotifications);
    unawaited(_syncNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager.removeListener(_syncNotifications);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_sessionManager.session.isActive) {
      return;
    }
    unawaited(serviceLocator<NotificationCubit>().reconcileAfterResume());
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
