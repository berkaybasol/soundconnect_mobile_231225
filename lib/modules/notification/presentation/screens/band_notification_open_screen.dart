import '../notification_direct_open.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../profile/presentation/screens/band_profile_screen.dart';
import '../../../profile/presentation/screens/band_invite_decision_screen.dart';
import '../../data/notification_target_repository.dart';
import '../cubit/notification_cubit.dart';
import '../notification_target_read.dart';

/// Native BAND entry resolves the owned occurrence before its exact business
/// destination. Neither a fallback nor a stale invitation acknowledges it.
class BandNotificationOpenScreen extends StatefulWidget {
  const BandNotificationOpenScreen({super.key, required this.target});
  final PushTarget target;
  @override
  State<BandNotificationOpenScreen> createState() =>
      _BandNotificationOpenScreenState();
}

class _BandNotificationOpenScreenState extends State<BandNotificationOpenScreen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<NotificationTargetRepository>();
  ModalRoute<dynamic>? _route;
  bool _initial = true, _scheduled = false, _busy = false, _opened = false;
  String? _error;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool get _current =>
      mounted &&
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      _session.expiresAt?.isAfter(DateTime.now()) == true &&
      _session.isActive &&
      !_session.isVenueApplicationSession &&
      !_session.requiresListenerProfileChoice &&
      _session.userId == widget.target.recipientId &&
      _session.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']) &&
      !_session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
      _route?.isActive != false &&
      _route?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    _session;
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
  void didPopNext() {
    _schedule();
    _showFailure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      _showFailure();
    }
  }

  void _schedule() {
    if (!mounted || !_initial || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && _initial) unawaited(_open());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open() async {
    if (!_current || !_foreground || _busy || _opened) return;
    _initial = false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repository.resolveBand(widget.target, _session);
      if (!_current ||
          !_foreground ||
          !result.isSuccess ||
          result.data == null) {
        return;
      }
      final item = result.data!;
      final bandId = item.payload['bandId'] as String;
      final ticket =
          item.type == 'BAND_INVITE_RECEIVED' ||
              item.type == 'BAND_MEMBER_REMOVED'
          ? NotificationTargetRead.venue(
              notification: item,
              cubit: serviceLocator<NotificationCubit>(),
              sessions: _sessions,
              repository: _repository,
            )
          : NotificationTargetRead.follow(
              notification: item,
              cubit: serviceLocator<NotificationCubit>(),
              sessions: _sessions,
              repository: _repository,
              targetId: bandId,
            );
      if (!mounted || !_current || !_foreground) return;
      if (item.type == 'BAND_INVITE_RECEIVED') {
        unawaited(
          NotificationDirectOpen.push<void>(
            context,
            ticket.attach(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/band-invitation'),
                builder: (_) => BandInviteDecisionScreen(
                  args: BandInviteDecisionScreenArgs(
                    bandId: bandId,
                    invitationId: item.payload['invitationId'] as String,
                    expectedSessionKey: item.recipientId,
                    title: item.title,
                    message: item.message,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        final removed = item.type == 'BAND_MEMBER_REMOVED';
        final routeName = removed
            ? AppRoutes.myBands
            : AppRoutes.bandMemberProfile;
        unawaited(
          NotificationDirectOpen.pushNamed<void>(
            context,
            routeName,
            arguments: ticket.argumentsFor(
              routeName,
              arguments: removed
                  ? null
                  : BandProfileScreenArgs(
                      bandId: bandId,
                      viewMode: BandProfileViewMode.auto,
                    ),
            ),
          ),
        );
      }
      _opened = true;
    } catch (_) {
      // No fallback destination or implicit read. Recovery is explicit below.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (!_opened) {
            _error ??= NotificationTargetRepository.unavailable.message;
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
