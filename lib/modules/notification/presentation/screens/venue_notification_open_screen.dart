import '../notification_direct_open.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../data/notification_target_repository.dart';
import '../cubit/notification_cubit.dart';
import '../navigation/venue_notification_navigation.dart';
import '../notification_target_read.dart';

/// Resolves on the current product page without adding an intermediate route.
class VenueNotificationOpenScreen extends StatefulWidget {
  const VenueNotificationOpenScreen({super.key, required this.target});
  final PushTarget target;
  @override
  State<VenueNotificationOpenScreen> createState() =>
      _VenueNotificationOpenScreenState();
}

class _VenueNotificationOpenScreenState
    extends State<VenueNotificationOpenScreen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<NotificationTargetRepository>();
  bool _initialAttemptPending = true;
  bool _initialAttemptScheduled = false;
  ModalRoute<dynamic>? _route;
  bool _busy = false;
  bool _opened = false;
  String? _error;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool get _current =>
      mounted &&
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      _session.isActive &&
      _route?.isActive != false &&
      _route?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    // Capture the authenticated session before the first frame can be replaced.
    _session;
    WidgetsBinding.instance.addObserver(this);
    _scheduleInitialAttempt();
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
  void didPopNext() {
    _scheduleInitialAttempt();
    _showFailure();
  }

  void _scheduleInitialAttempt() {
    if (!mounted || !_initialAttemptPending || _initialAttemptScheduled) return;
    _initialAttemptScheduled = true;
    // Route callbacks can run while the navigator is locked. Recheck the
    // captured session, foreground and route after that frame has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAttemptScheduled = false;
      if (mounted && _initialAttemptPending) unawaited(_open());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleInitialAttempt();
      _showFailure();
    }
  }

  Future<void> _open() async {
    if (!_current || _busy || _opened || !_foreground) return;
    // Native taps can mount this route before Android returns focus. Do not
    // resolve successfully only to have navigation reject that initial frame.
    // Once attempted, failures still require an explicit retry, never resume.
    _initialAttemptPending = false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repository.resolve(widget.target, _session);
      if (!mounted || !_current || !_foreground) return;
      final item = result.data;
      if (!result.isSuccess || item == null) return;
      final cubit = serviceLocator<NotificationCubit>();
      await VenueNotificationNavigation(
        context,
        item,
        replaceOrigin: true,
        readTicket: NotificationTargetRead.venue(
          notification: item,
          cubit: cubit,
          sessions: _sessions,
          repository: _repository,
        ),
        onOpened: () => _opened = true,
      ).open();
    } catch (_) {
      // Every attempted but unopened result exposes explicit recovery below.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          // A response discarded under a cover must not leave a spinner after
          // returning. Keep the attempt consumed: only the retry button retries.
          if (!_opened) {
            _error = NotificationTargetRepository.unavailable.message;
          }
        });
      }
      _showFailure();
    }
  }

  void _showFailure() {
    if (!mounted || !_current || !_foreground || _opened || _error == null) {
      return;
    }
    NotificationDirectOpen.feedback(
      context,
      message: _error ?? 'Bu bildirim şu anda açılamıyor.',
      retry: () => unawaited(_open()),
      isCurrent: () => _current && _foreground && !_opened,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
