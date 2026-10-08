import '../notification_direct_open.dart';
import 'dart:async';
import '../notification_profile_selection.dart';
import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../profile/presentation/screens/band_profile_screen.dart';
import '../../data/notification_target_repository.dart';
import '../cubit/notification_cubit.dart';
import '../notification_target_read.dart';

/// Shared native/inbox entry. It resolves a fresh exact notification, then a
/// fresh public target; only the destination's real content can acknowledge it.
class FollowNotificationOpenScreen extends StatefulWidget {
  const FollowNotificationOpenScreen({super.key, required this.target});
  final PushTarget target;
  @override
  State<FollowNotificationOpenScreen> createState() =>
      _FollowNotificationOpenScreenState();
}

class _FollowNotificationOpenScreenState
    extends State<FollowNotificationOpenScreen>
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
      final result = await _repository.resolveFollow(widget.target, _session);
      if (!_current ||
          !_foreground ||
          !result.isSuccess ||
          result.data == null) {
        return;
      }
      final item = result.data!;
      String routeName, targetId;
      String? targetUserId;
      Object arguments;
      if (item.type == 'SOCIAL_NEW_BAND_FOLLOWER') {
        targetId = item.payload['bandId'] as String;
        routeName = AppRoutes.bandMemberProfile;
        arguments = BandProfileScreenArgs(
          bandId: targetId,
          viewMode: BandProfileViewMode.auto,
        );
      } else {
        targetUserId = item.payload['followerId'] as String;
        final resolver = serviceLocator<DmUserProfileResolver>();
        if (resolver is! FollowUserProfileResolver) return;
        final followResolver = resolver as FollowUserProfileResolver;
        final resolved = await followResolver.resolveFreshForFollow(
          userId: targetUserId,
          session: _session,
        );
        if (!mounted || !_current || !_foreground || !resolved.isSuccess) {
          return;
        }
        final targets =
            resolved.data
                ?.where(
                  (t) => !t.isStudioRestricted && dmProfileRouteFor(t) != null,
                )
                .toList() ??
            <DmProfileTarget>[];
        if (targets.isEmpty) {
          _error = 'Bu bildirimin profili şu anda kullanılamıyor.';
          return;
        }
        final selected = await selectNotificationProfile(
          context: context,
          profiles: targets,
          resolver: followResolver,
          userId: targetUserId,
          session: _session,
          isCurrent: () => _current && _foreground,
        );
        if (!mounted || !_current || !_foreground || selected == null) {
          _error = 'Profil seçimi tamamlanmadı.';
          return;
        }
        final destination = dmProfileRouteFor(selected);
        if (destination == null ||
            destination.routeName == AppRoutes.studioListenerInfo) {
          return;
        }
        targetId = selected.id;
        routeName = destination.routeName;
        arguments = destination.arguments;
      }
      if (!mounted || !_current || !_foreground) return;
      final ticket = NotificationTargetRead.follow(
        notification: item,
        cubit: serviceLocator<NotificationCubit>(),
        sessions: _sessions,
        repository: _repository,
        targetId: targetId,
        targetUserId: targetUserId,
      );
      // No navigator-wide lock survives a successful dispatch. Another follow
      // notification can enter while this destination remains in the stack.
      unawaited(
        NotificationDirectOpen.pushNamed<void>(
          context,
          routeName,
          arguments: ticket.argumentsFor(routeName, arguments: arguments),
        ),
      );
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
