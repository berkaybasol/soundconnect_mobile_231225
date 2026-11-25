import '../modules/notification/presentation/notification_direct_open.dart';
import '../modules/notification/presentation/screens/custom_notification_open_screen.dart';
import '../modules/auth/presentation/screens/venue_application_decision_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'dart:async';
import '../modules/notification/presentation/screens/follow_notification_open_screen.dart';
import '../modules/notification/presentation/screens/band_notification_open_screen.dart';
import '../modules/notification/presentation/screens/table_notification_open_screen.dart';
import '../modules/notification/presentation/screens/inbox_product_notification_open.dart';
import '../modules/notification/presentation/screens/media_notification_open_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/auth_session.dart';
import '../core/auth/auth_session_manager.dart';
import '../core/auth/session_access_monitor.dart';
import '../core/realtime/realtime_client_error.dart';
import '../modules/notification/data/notification_realtime_client.dart';
import '../modules/auth/presentation/screens/account_suspended_screen.dart';
import '../core/auth/jwt_claims.dart';
import '../core/deep_link/app_deep_link.dart';
import '../core/deep_link/app_deep_link_policy.dart';
import '../core/deep_link/pending_app_deep_link_store.dart';
import '../core/diagnostics/app_diagnostics.dart';
import '../core/di/service_locator.dart';
import '../core/push/push_coordinator.dart';
import '../modules/dm/presentation/screens/dm_notification_open_screen.dart';
import '../modules/dm/presentation/cubit/dm_badge_cubit.dart';
import '../modules/dm/presentation/dm_chat_route_observer.dart';
import '../modules/notification/presentation/notification_target_read.dart';
import '../modules/admin/presentation/screens/admin_dashboard_screen.dart';
import '../modules/analytics/presentation/widgets/analytics_exposure.dart';
import '../modules/auth/presentation/screens/login_screen.dart';
import '../modules/auth/presentation/screens/venue_pending_screen.dart';
import '../modules/auth/presentation/cubit/auth_cubit.dart';
import '../modules/event/presentation/screens/guest_event_home_screen.dart';
import '../modules/event/presentation/screens/event_discovery_screen.dart';
import 'backstage_home_screen.dart';
import '../modules/profile/presentation/profile_visual_theme.dart';
import '../modules/profile/presentation/screens/musician_profile_screen.dart';
import '../modules/profile/presentation/screens/studio_profile_screen.dart';
import '../modules/profile/presentation/screens/venue_profile_screen.dart';
import '../modules/auth/presentation/screens/listener_profile_choice_screen.dart';
import '../modules/profile/domain/profile_media_upload_repository.dart';
import '../modules/location/presentation/cubit/location_cubit.dart';
import '../modules/notification/presentation/cubit/notification_cubit.dart';
import '../modules/notification/presentation/screens/venue_notification_open_screen.dart';
import '../modules/notification/presentation/screens/studio_reservation_notification_open_screen.dart';
import '../modules/collab/presentation/collab_route_args.dart';
import '../shared/theme/app_theme.dart';
import '../shared/theme/app_theme_controller.dart';
import 'router/app_route_guard.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

enum AppLaunchTarget {
  guest,
  login,
  home,
  musicianProfile,
  venueProfile,
  studioProfile,
  eventDiscovery,
  listenerProfileChoice,
  admin,
  venuePending,
  studioPending,
  studioRejected,
}

bool shouldStartAuthenticatedSessionServices(AuthSession session) =>
    session.isAuthenticated &&
    session.isActive &&
    !session.requiresListenerProfileChoice;

String? resolveSessionChangeNavigationRoute({
  required bool wasAuthenticated,
  required bool wasListenerChoiceRequired,
  required AuthSession current,
  String? previousUserId,
  String? previousToken,
  AuthSession? previousSession,
  bool accountResetPending = false,
  bool isRotatingCurrentLogin = false,
}) {
  if (current.isSuspendedNotice) return AppRoutes.accountSuspended;
  if (previousSession?.isSuspendedNotice == true) return AppRoutes.login;
  if (wasAuthenticated && !current.isAuthenticated) return AppRoutes.login;
  final approvalRoute = resolveMembershipApprovalRoute(
    previousSession,
    current,
  );
  if (approvalRoute != null) return approvalRoute;
  if (accountResetPending) return AppRouteGuard.landingRouteFor(current);
  if (wasAuthenticated &&
      current.isAuthenticated &&
      ((previousUserId != null && previousUserId != current.userId) ||
          (previousToken != null &&
              previousToken != current.token &&
              !isRotatingCurrentLogin))) {
    return AppRouteGuard.landingRouteFor(current);
  }
  if (current.isAuthenticated &&
      current.requiresListenerProfileChoice &&
      !wasListenerChoiceRequired) {
    return AppRoutes.listenerProfileChoice;
  }
  return null;
}

String? resolveMembershipApprovalRoute(
  AuthSession? previous,
  AuthSession current,
) {
  if (previous == null ||
      !previous.isAuthenticated ||
      previous.userId == null ||
      previous.userId != current.userId) {
    return null;
  }
  final route = AppRouteGuard.approvedMembershipProfileFor(current);
  if (previous.isPendingVenue && route == AppRoutes.venueProfile) return route;
  if (previous.isPendingStudio && route == AppRoutes.studioProfile) {
    return route;
  }
  return null;
}

AppLaunchTarget resolveLaunchTarget(String? token, {DateTime? now}) {
  return JwtClaims.tryParse(token, now: now) == null
      ? AppLaunchTarget.guest
      : AppLaunchTarget.home;
}

AppLaunchTarget resolveSessionLaunchTarget(AuthSession session) {
  if (!session.isAuthenticated) return AppLaunchTarget.guest;
  return switch (AppRouteGuard.landingRouteFor(session)) {
    AppRoutes.venuePending => AppLaunchTarget.venuePending,
    AppRoutes.studioPending => AppLaunchTarget.studioPending,
    AppRoutes.studioRejected => AppLaunchTarget.studioRejected,
    AppRoutes.adminDashboard => AppLaunchTarget.admin,
    AppRoutes.musicianProfile => AppLaunchTarget.musicianProfile,
    AppRoutes.venueProfile => AppLaunchTarget.venueProfile,
    AppRoutes.studioProfile => AppLaunchTarget.studioProfile,
    AppRoutes.eventDiscovery => AppLaunchTarget.eventDiscovery,
    AppRoutes.listenerProfileChoice => AppLaunchTarget.listenerProfileChoice,
    AppRoutes.home => AppLaunchTarget.home,
    _ => AppLaunchTarget.login,
  };
}

class SoundConnectApp extends StatefulWidget {
  final Future<String?>? initialTokenFuture;
  final AppLinkSource? appLinkSource;
  final AppDeepLinkInbox? appDeepLinkInbox;

  const SoundConnectApp({
    super.key,
    this.initialTokenFuture,
    this.appLinkSource,
    this.appDeepLinkInbox,
  });

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp>
    with WidgetsBindingObserver {
  late final Future<AuthSession> _initialSessionFuture;
  late final AuthSessionManager _sessionManager;
  late final SessionAccessMonitor _access;
  StreamSubscription<RealtimeClientError>? _socketErrors;
  bool _showLoginAtRoot = false;
  bool _navigatorShown = false;
  Future<void>? _suspendedLinkCleanup;
  late final AppDeepLinkInbox _appDeepLinkInbox;
  late final _CurrentRouteObserver _routeObserver;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _appLinkSubscription;
  bool _wasAuthenticated = false;
  String? _previousUserId;
  String? _previousToken;
  AuthSession? _previousSession;
  bool _wasListenerChoiceRequired = false;
  bool _sessionRouteResetPending = false;
  bool _observedInitialSessionState = false;
  bool _sessionRestoreCompleted = false;
  bool _processingPendingLink = false;
  bool _processPendingLinkAgain = false;
  bool _pendingLinkFrameScheduled = false;
  String? _lastAccessNoticeIdentity;
  PushCoordinator? _push;
  bool _pushNavigationInFlight = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = serviceLocator<AuthSessionManager>();
    _access = SessionAccessMonitor(_sessionManager);
    WidgetsBinding.instance.addObserver(this);
    _access.addListener(_schedulePendingLinkProcessing);
    if (_sessionManager.verifyAccess != null &&
        serviceLocator.isRegistered<NotificationRealtimeClient>()) {
      _socketErrors = serviceLocator<NotificationRealtimeClient>().errorStream
          .listen((error) {
            if (error.type != RealtimeClientErrorType.invalidPayload) {
              _access.onSocketLoss();
            }
          });
    }
    _appDeepLinkInbox =
        widget.appDeepLinkInbox ?? serviceLocator<AppDeepLinkInbox>();
    _routeObserver = _CurrentRouteObserver(_schedulePendingLinkProcessing);
    _sessionManager.addListener(_onSessionChanged);
    _initialSessionFuture = _sessionManager.restore(
      tokenOverride: widget.initialTokenFuture,
    );
    if (serviceLocator.isRegistered<PushCoordinator>()) {
      _push = serviceLocator<PushCoordinator>();
      _push!.addListener(_schedulePendingLinkProcessing);
      unawaited(_push!.start(initialSession: _initialSessionFuture));
    }
    unawaited(
      _initialSessionFuture.then((_) {
        if (!mounted) return;
        _sessionRestoreCompleted = true;
        _schedulePendingLinkProcessing();
      }),
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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_socketErrors?.cancel());
    _access.removeListener(_schedulePendingLinkProcessing);
    _access.dispose();
    _sessionManager.removeListener(_onSessionChanged);
    _push?.removeListener(_schedulePendingLinkProcessing);
    unawaited(_appLinkSubscription?.cancel());
    super.dispose();
  }

  Future<void> _onIncomingAppLink(Uri uri) async {
    if (_sessionManager.session.isSuspendedNotice) return;
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
      unawaited(_processPendingPush());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _processPendingPush() async {
    if (!mounted ||
        _access.blocksContent ||
        _sessionManager.session.isSuspendedNotice ||
        !_sessionRestoreCompleted ||
        _pushNavigationInFlight ||
        _routeObserver.currentRouteName == AppRoutes.login) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final target = _push?.consumePending();
    if (target == null) return;
    _pushNavigationInFlight = true;
    final session = _sessionManager.session;
    try {
      if (target.isVenueApplication) {
        navigator.push<void>(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/venue-application-decision'),
            builder: (_) => VenueApplicationDecisionScreen(target: target),
          ),
        );
        return;
      }
      final Widget? opener = target.type == 'ADMIN_BROADCAST'
          ? CustomNotificationOpenScreen(target: target)
          : target.isCollab || target.isOverthinking
          ? InboxProductNotificationOpen.native(target: target)
          : target.isTable
          ? TableNotificationOpenScreen.native(target: target)
          : target.isBand
          ? BandNotificationOpenScreen(target: target)
          : target.isMedia
          ? MediaNotificationOpenScreen(target: target)
          : target.isFollow
          ? FollowNotificationOpenScreen(target: target)
          : target.isVenue
          ? VenueNotificationOpenScreen(target: target)
          : target.isStudio
          ? StudioReservationNotificationOpenScreen(target: target)
          : target.type == 'DM_NEW_MESSAGE'
          ? DmNotificationOpenScreen(target: target)
          : null;
      if (opener != null) {
        unawaited(
          NotificationDirectOpen.start(
            navigator.context,
            identity: target.notificationId,
            builder: (_) => opener,
          ),
        );
        return;
      }
      if (mounted &&
          _sessionManager.session.token == session.token &&
          _sessionManager.session.userId == session.userId &&
          shouldStartAuthenticatedSessionServices(_sessionManager.session)) {
        navigator.pushNamed<void>(AppRoutes.notifications);
      }
    } catch (_) {
      // A failed open must not replace its target with a generic inbox.
      if (mounted &&
          _sessionManager.session.token == session.token &&
          _sessionManager.session.userId == session.userId &&
          shouldStartAuthenticatedSessionServices(_sessionManager.session)) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Bildirim şu anda açılamıyor.')),
        );
      }
    } finally {
      _pushNavigationInFlight = false;
      if (_push?.pending != null) _schedulePendingLinkProcessing();
    }
  }

  Future<void> _processPendingAppLink() async {
    if (!_sessionRestoreCompleted ||
        _access.blocksContent ||
        _sessionManager.session.isSuspendedNotice) {
      return;
    }
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
    if (!mounted ||
        pending == null ||
        _access.blocksContent ||
        _sessionManager.session.isSuspendedNotice) {
      return;
    }
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
    if (!mounted ||
        _access.blocksContent ||
        !identical(_sessionManager.session, session)) {
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
              appSnackBar(
                _messengerKey.currentState!.context,
                tone: AppSnackBarTone.warning,
                content: const Text(
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
    final session = _sessionManager.session;
    if (session.isSuspendedNotice) {
      _showLoginAtRoot = true;
      _navigatorShown = false;
      _suspendedLinkCleanup = _discardSuspendedLink();
      _messengerKey.currentState?.clearSnackBars();
    }
    if (_wasAuthenticated && !session.isAuthenticated) _showLoginAtRoot = true;
    if (session.isSuspendedNotice ||
        _previousSession?.isSuspendedNotice == true ||
        (_wasAuthenticated && !session.isAuthenticated)) {
      setState(() {});
    }
    final isAuthenticated = session.isAuthenticated;
    final listenerChoiceRequired =
        isAuthenticated && session.requiresListenerProfileChoice;
    if (!_observedInitialSessionState) {
      _observedInitialSessionState = true;
      _wasAuthenticated = isAuthenticated;
      _previousUserId = session.userId;
      _previousToken = session.token;
      _previousSession = session;
      _wasListenerChoiceRequired = listenerChoiceRequired;
      return;
    }
    final approvalRoute = resolveMembershipApprovalRoute(
      _previousSession,
      session,
    );
    final destination = resolveSessionChangeNavigationRoute(
      wasAuthenticated: _wasAuthenticated,
      wasListenerChoiceRequired: _wasListenerChoiceRequired,
      current: session,
      previousUserId: _previousUserId,
      previousToken: _previousToken,
      previousSession: _previousSession,
      accountResetPending: _sessionRouteResetPending,
      isRotatingCurrentLogin: _sessionManager.isRotatingCurrentLogin,
    );
    _wasAuthenticated = isAuthenticated;
    _previousUserId = session.userId;
    _previousToken = session.token;
    _previousSession = session;
    _wasListenerChoiceRequired = listenerChoiceRequired;
    if (destination == null) return;
    _sessionRouteResetPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _sessionManager.session.isSuspendedNotice !=
              session.isSuspendedNotice ||
          _sessionManager.session.token != session.token ||
          _sessionManager.session.userId != session.userId) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      _sessionRouteResetPending = false;
      if (_routeObserver.currentRouteName == destination) return;
      navigator.pushNamedAndRemoveUntil(destination, (route) => false);
      if (approvalRoute != null) {
        final messenger = _messengerKey.currentState;
        messenger?.showSnackBar(
          appSnackBar(
            messenger.context,
            tone: AppSnackBarTone.success,
            duration: const Duration(seconds: 3),
            content: Text(
              approvalRoute == AppRoutes.venueProfile
                  ? 'Mekân başvurun onaylandı. Profilin hazır!'
                  : 'Stüdyo başvurun onaylandı. Profilin hazır!',
            ),
          ),
        );
      }
    });
  }

  Future<void> _discardSuspendedLink() async {
    final pending = await _appDeepLinkInbox.pending();
    if (pending != null && _sessionManager.session.isSuspendedNotice) {
      await _appDeepLinkInbox.complete(pending);
    }
  }

  Future<void> _returnFromSuspension() async {
    await _suspendedLinkCleanup;
    if (mounted) await _sessionManager.dismissSuspension();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _access.setForeground(true);
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _access.setForeground(false);
    }
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
            access: _access,
            child: ListenableBuilder(
              listenable: AppThemeController.instance,
              builder: (context, _) => MaterialApp(
                navigatorKey: _navigatorKey,
                scaffoldMessengerKey: _messengerKey,
                navigatorObservers: <NavigatorObserver>[
                  notificationTargetRouteObserver,
                  _routeObserver,
                  analyticsRouteObserver,
                  dmChatRouteObserver,
                ],
                title: 'Soundconnect',
                theme: AppTheme.current,
                themeMode:
                    AppThemeController.instance.variant == AppThemeVariant.light
                    ? ThemeMode.light
                    : ThemeMode.dark,
                themeAnimationDuration: Duration.zero,
                onGenerateRoute: AppRouter.onGenerateRoute,
                builder: (context, navigator) => ListenableBuilder(
                  listenable: Listenable.merge([_sessionManager, _access]),
                  builder: (context, _) {
                    if (_sessionManager.session.isSuspendedNotice) {
                      return AccountSuspendedScreen(
                        onReturnToLogin: _returnFromSuspension,
                      );
                    }
                    final blocked = _access.blocksContent;
                    // Retain the active route during a resume check. On cold start,
                    // postpone building private screens until their bearer is verified.
                    if (!blocked && !waitingForToken) _navigatorShown = true;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!blocked || _navigatorShown)
                          Offstage(
                            offstage: blocked,
                            child: ExcludeFocus(
                              excluding: blocked,
                              child: TickerMode(
                                enabled: !blocked,
                                child: navigator!,
                              ),
                            ),
                          ),
                        if (blocked)
                          _access.state == SessionAccessState.unavailable
                              ? SessionAccessUnavailableScreen(
                                  onRetry: _access.check,
                                )
                              : const _LaunchLoadingScreen(),
                      ],
                    );
                  },
                ),
                home: waitingForToken
                    ? _LaunchLoadingScreen()
                    : _showLoginAtRoot &&
                          !_sessionManager.session.isAuthenticated
                    ? LoginScreen()
                    : switch (launchTarget) {
                        AppLaunchTarget.home => const BackstageHomeScreen(),
                        AppLaunchTarget.musicianProfile =>
                          const ProfileVisualThemeScope(
                            child: MusicianProfileScreen(),
                          ),
                        AppLaunchTarget.venueProfile =>
                          const ProfileVisualThemeScope(
                            child: VenueProfileScreen(),
                          ),
                        AppLaunchTarget.studioProfile =>
                          const ProfileVisualThemeScope(
                            child: StudioProfileScreen(),
                          ),
                        AppLaunchTarget.eventDiscovery =>
                          const MemberEventDiscoveryScreen(),
                        AppLaunchTarget.listenerProfileChoice =>
                          const ListenerProfileChoiceScreen(),
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
  final SessionAccessMonitor access;

  const _NotificationBootstrap({required this.child, required this.access});

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap>
    with WidgetsBindingObserver {
  late final AuthSessionManager _sessionManager;
  int _syncGeneration = 0;

  @override
  void initState() {
    super.initState();
    _sessionManager = serviceLocator<AuthSessionManager>();
    WidgetsBinding.instance.addObserver(this);
    _sessionManager.addListener(_syncNotifications);
    widget.access.addListener(_syncNotifications);
    unawaited(_syncNotifications());
  }

  @override
  void dispose() {
    _syncGeneration += 1;
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager.removeListener(_syncNotifications);
    widget.access.removeListener(_syncNotifications);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || widget.access.blocksContent) {
      return;
    }
    if (_sessionManager.session.canRegisterPush &&
        serviceLocator.isRegistered<PushCoordinator>()) {
      unawaited(serviceLocator<PushCoordinator>().reconcile());
    }
    if (!shouldStartAuthenticatedSessionServices(_sessionManager.session)) {
      return;
    }
    unawaited(serviceLocator<NotificationCubit>().reconcileAfterResume());
    if (serviceLocator.isRegistered<DmBadgeCubit>()) {
      unawaited(serviceLocator<DmBadgeCubit>().reconcileAfterResume());
    }
  }

  Future<void> _syncNotifications() async {
    final generation = ++_syncGeneration;
    if (widget.access.blocksContent) return;
    final cubit = serviceLocator<NotificationCubit>();
    if (shouldStartAuthenticatedSessionServices(_sessionManager.session)) {
      await cubit.ensureStarted();
      if (generation != _syncGeneration ||
          !shouldStartAuthenticatedSessionServices(_sessionManager.session)) {
        if (!shouldStartAuthenticatedSessionServices(_sessionManager.session)) {
          await cubit.stop();
        }
        return;
      }
      if (serviceLocator.isRegistered<DmBadgeCubit>()) {
        unawaited(serviceLocator<DmBadgeCubit>().ensureStarted());
      }
      unawaited(
        serviceLocator<ProfileMediaUploadRepository>().resumePendingUploads(),
      );
    } else {
      await cubit.stop();
      if (generation == _syncGeneration &&
          serviceLocator.isRegistered<DmBadgeCubit>()) {
        await serviceLocator<DmBadgeCubit>().stop();
      }
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
