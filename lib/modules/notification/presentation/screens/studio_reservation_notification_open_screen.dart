import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../profile/presentation/screens/profile_route_args.dart';
import '../../../profile/presentation/screens/studio_profile_screen.dart';
import '../../data/notification_target_repository.dart';
import '../cubit/notification_cubit.dart';
import '../notification_direct_open.dart';
import '../notification_target_read.dart';

/// Shared native/inbox coordination; only the real calendar/profile is a route.
class StudioReservationNotificationOpenScreen extends StatefulWidget {
  const StudioReservationNotificationOpenScreen({
    super.key,
    required this.target,
  });
  final PushTarget target;
  @override
  State<StudioReservationNotificationOpenScreen> createState() =>
      _StudioReservationNotificationOpenScreenState();
}

class _StudioReservationNotificationOpenScreenState
    extends State<StudioReservationNotificationOpenScreen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<NotificationTargetRepository>();
  ModalRoute<dynamic>? _route;
  bool _initial = true, _scheduled = false, _busy = false;
  bool _deferredFailure = false;
  int _generation = 0;
  bool get _sessionCurrent =>
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      _session.isActive &&
      _session.expiresAt?.isAfter(DateTime.now()) == true &&
      !_session.isVenueApplicationSession &&
      !_session.requiresListenerProfileChoice &&
      !_session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
      _session.userId?.toLowerCase() == widget.target.recipientId.toLowerCase();
  bool get _visible =>
      mounted &&
      _sessionCurrent &&
      _route?.isCurrent == true &&
      _route?.isActive == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    _session;
    _sessions.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = NotificationDirectOpen.routeOf(context);
    if (!identical(_route, route)) {
      notificationTargetRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) notificationTargetRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant StudioReservationNotificationOpenScreen old) {
    super.didUpdateWidget(old);
    if (old.target.notificationId != widget.target.notificationId ||
        old.target.recipientId != widget.target.recipientId ||
        old.target.type != widget.target.type) {
      _generation++;
      _busy = false;
      _initial = true;
      _schedule();
    }
  }

  void _sessionChanged() {
    if (!mounted || _sessionCurrent) return;
    _generation++;
    _busy = false;
  }

  @override
  void didPopNext() => _resume();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resume();
  }

  void _resume() {
    if (_deferredFailure && _visible) {
      _deferredFailure = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_visible) _showUnavailable();
      });
    }
    _schedule();
  }

  void _schedule() {
    if (!mounted || !_initial || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_initial && _visible) unawaited(_open());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _open() async {
    if (!_visible || _busy) return;
    _initial = false;
    _busy = true;
    _deferredFailure = false;
    final generation = ++_generation;
    try {
      final response = await _repository.resolveStudio(widget.target, _session);
      if (!mounted || generation != _generation) return;
      if (!_visible) {
        _deferredFailure = _sessionCurrent;
        return;
      }
      final target = response.data;
      if (!response.isSuccess || target == null) {
        _showUnavailable();
        return;
      }
      final route = MaterialPageRoute<void>(
        settings: target.roomArchived && !target.ownerMode
            ? RouteSettings(
                arguments: PublicProfileArgs(
                  profileId: target.studioProfileId,
                  viewerUserId: _session.userId,
                ),
              )
            : null,
        builder: (_) => _StudioNotificationSessionGuard(
          sessions: _sessions,
          session: _session,
          child: target.roomArchived
              ? NotificationTerminalFeedback(
                  message: 'Rezervasyonun odası arşivlendi.',
                  contentIdentity: target,
                  child: target.ownerMode
                      ? const StudioProfileScreen()
                      : const StudioPublicProfileScreen(),
                )
              : StudioReservationCalendarScreen(
                  args: StudioReservationCalendarArgs(
                    roomId: target.roomId,
                    studioProfileId: target.studioProfileId,
                    ownerMode: target.ownerMode,
                    timeZone: target.zoneId,
                    reservationDate: DateTime.parse(target.localDate),
                    reservationId: target.reservationId,
                    notificationTarget: target,
                  ),
                ),
        ),
      );
      NotificationTargetRead.content(
        notification: target.notification,
        cubit: serviceLocator<NotificationCubit>(),
        sessions: _sessions,
        repository: _repository,
        content: target,
      ).attach(route);
      unawaited(NotificationDirectOpen.push(context, route));
    } catch (_) {
      if (mounted && generation == _generation && _visible) _showUnavailable();
    } finally {
      if (mounted && generation == _generation) _busy = false;
    }
  }

  void _showUnavailable() => NotificationDirectOpen.feedback(
    context,
    message: 'Bu rezervasyon şu anda açılamıyor.',
    retry: () => unawaited(_open()),
    isCurrent: () => _visible,
  );
  @override
  void dispose() {
    _generation++;
    _sessions.removeListener(_sessionChanged);
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Remove a captured private destination when its account/token is replaced.
class _StudioNotificationSessionGuard extends StatefulWidget {
  const _StudioNotificationSessionGuard({
    required this.sessions,
    required this.session,
    required this.child,
  });
  final AuthSessionManager sessions;
  final AuthSession session;
  final Widget child;
  @override
  State<_StudioNotificationSessionGuard> createState() =>
      _StudioNotificationSessionGuardState();
}

class _StudioNotificationSessionGuardState
    extends State<_StudioNotificationSessionGuard> {
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_changed);
  }

  void _changed() {
    if (!mounted || identical(widget.sessions.session, widget.session)) return;
    setState(() => _valid = false);
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || route == null || !route.isActive) return;
      navigator.removeRoute(route);
    });
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _valid ? widget.child : const SizedBox.shrink();
}
