import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_route_guard.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../../shared/event_performer_identity.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../profile/presentation/screens/media_detail_screen.dart';
import '../../../profile/presentation/screens/weekly_event_detail_screen.dart';
import '../../data/custom_notification_repository.dart';
import '../../data/notification_target_repository.dart';
import '../cubit/notification_cubit.dart';
import '../notification_direct_open.dart';
import '../notification_target_read.dart';
import '../notification_profile_selection.dart';

/// Invisible coordination shared by native taps and inbox selection. The
/// destination and read proof always come from the current authorized API.
class CustomNotificationOpenScreen extends StatefulWidget {
  const CustomNotificationOpenScreen({super.key, required this.target});
  final PushTarget target;
  @override
  State<CustomNotificationOpenScreen> createState() => _CustomOpenState();
}

class _CustomOpenState extends State<CustomNotificationOpenScreen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<CustomNotificationRepository>();
  ModalRoute<dynamic>? _origin;
  bool _initial = true, _scheduled = false, _busy = false, _opened = false;
  String? _error;
  CustomNotificationDestination? _terminal;
  NotificationTargetRead? _terminalTicket;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool get _current =>
      mounted &&
      _repository.current(_session) &&
      _session.userId == widget.target.recipientId &&
      _origin?.isActive == true &&
      _origin?.isCurrent == true;

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
    final origin = NotificationDirectOpen.routeOf(context);
    if (!identical(origin, _origin)) {
      notificationTargetRouteObserver.unsubscribe(this);
      _origin = origin;
      if (origin != null) {
        notificationTargetRouteObserver.subscribe(this, origin);
      }
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

  NotificationTargetRead _ticket(
    CustomNotificationDestination value,
    Object content,
  ) => NotificationTargetRead.content(
    notification: value.notification,
    cubit: serviceLocator<NotificationCubit>(),
    sessions: _sessions,
    repository: serviceLocator<NotificationTargetRepository>(),
    content: content,
  );

  Future<void> _open() async {
    if (!_current || !_foreground || _busy || _opened || _terminal != null) {
      return;
    }
    _initial = false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repository.resolve(widget.target, _session);
      if (!_current || !_foreground) return;
      final value = result.data;
      if (!result.isSuccess || value == null) return;
      if (!value.available) {
        setState(() {
          _terminal = value;
          _terminalTicket = _ticket(value, value);
        });
        return;
      }
      switch (value.kind) {
        case 'PROFILE':
          await _profile(value);
        case 'CONTENT':
          _media(value);
        case 'EVENT':
          _event(value);
        default:
          _module(value);
      }
    } catch (_) {
      // API/parse/route failures are not exact terminal results and never ACK.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (!_opened && _terminal == null) {
            _error ??= NotificationTargetRepository.unavailable.message;
          }
        });
        _showFailure();
      }
    }
  }

  Future<void> _profile(CustomNotificationDestination value) async {
    final resolver = serviceLocator<DmUserProfileResolver>();
    if (resolver is! FollowUserProfileResolver) return;
    final result = await (resolver as FollowUserProfileResolver)
        .resolveFreshForFollow(userId: value.targetId!, session: _session);
    if (!mounted || !_current || !_foreground || !result.isSuccess) return;
    final profile = await selectNotificationProfile(
      context: context,
      profiles:
          result.data
              ?.where(
                (p) => !p.isStudioRestricted && dmProfileRouteFor(p) != null,
              )
              .toList() ??
          [],
      resolver: resolver as FollowUserProfileResolver,
      userId: value.targetId!,
      session: _session,
      isCurrent: () => _current && _foreground,
    );
    if (!mounted || !_current || !_foreground || profile == null) return;
    final route = dmProfileRouteFor(profile);
    if (route == null ||
        AppRouteGuard.redirectFor(route.routeName, _session) != null) {
      return;
    }
    final ticket = NotificationTargetRead.follow(
      notification: value.notification,
      cubit: serviceLocator<NotificationCubit>(),
      sessions: _sessions,
      repository: serviceLocator<NotificationTargetRepository>(),
      targetId: profile.id,
      targetUserId: value.targetId,
    );
    unawaited(
      NotificationDirectOpen.pushNamed<void>(
        context,
        route.routeName,
        arguments: ticket.argumentsFor(
          route.routeName,
          arguments: route.arguments,
        ),
      ),
    );
    _opened = true;
  }

  void _media(CustomNotificationDestination value) {
    final media = value.media!;
    final ticket = _ticket(value, media);
    unawaited(
      NotificationDirectOpen.push<void>(
        context,
        ticket.attach(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/notification-media/${media.id}'),
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => serviceLocator<InteractionStatsCubit>(),
                ),
                BlocProvider(
                  create: (_) => serviceLocator<CommentThreadCubit>(),
                ),
              ],
              child: MediaDetailScreen(
                key: ValueKey(media.id),
                title: media.title?.trim().isNotEmpty == true
                    ? media.title!
                    : 'İçerik',
                isVideo: media.kind == 'VIDEO',
                isImage: media.kind == 'IMAGE',
                playbackUrl: media.playbackUrl ?? media.sourceUrl,
                imageUrl: media.sourceUrl,
                thumbnailUrl: media.thumbnailUrl,
                durationSeconds: media.durationSeconds,
                targetType: 'MEDIA',
                targetId: media.id,
                likeCount: null,
                commentCount: null,
                notificationContent: media,
              ),
            ),
          ),
        ),
      ),
    );
    _opened = true;
  }

  void _event(CustomNotificationDestination value) {
    final raw = value.event!;
    final performer = EventPerformerIdentity.fromWire(
      performerType: raw['performerType'],
      musicianProfileId: raw['musicianProfileId'],
      bandId: raw['bandId'],
    );
    String text(String key) => raw[key] is String ? raw[key] as String : '';
    final event = WeeklyCalendarEvent(
      id: value.targetId!,
      title: text('title'),
      artistName: text('performerName'),
      artistProfileId: performer.musicianProfileId,
      bandProfileId: performer.bandId,
      performerType: performer.performerType,
      venueName: text('venueName'),
      venueId: raw['venueId'] as String?,
      city: text('venueCity'),
      district: text('venueDistrict'),
      neighborhood: text('venueNeighborhood'),
      eventDate: text('eventDate'),
      startTime: text('startTime'),
      endTime: text('endTime'),
      imageAssetPath: raw['posterImage'] as String?,
      description: text('description'),
    );
    unawaited(
      NotificationDirectOpen.push<void>(
        context,
        _ticket(value, event).attach(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/event/${event.id}'),
            builder: (_) => WeeklyEventDetailScreen(event: event),
          ),
        ),
      ),
    );
    _opened = true;
  }

  void _module(CustomNotificationDestination value) {
    final name = switch (value.kind) {
      'HOME' => AppRouteGuard.startRouteFor(_session),
      'EVENTS' => AppRoutes.eventDiscovery,
      'TABLES' => AppRoutes.tableGroupList,
      'COLLAB' => AppRoutes.collabDiscovery,
      'MARKETPLACE' => AppRoutes.marketplace,
      _ => null,
    };
    if (name == null || AppRouteGuard.redirectFor(name, _session) != null) {
      return;
    }
    final ticket = NotificationTargetRead.module(
      notification: value.notification,
      cubit: serviceLocator<NotificationCubit>(),
      sessions: _sessions,
      repository: serviceLocator<NotificationTargetRepository>(),
      kind: value.kind,
      content: value,
    );
    unawaited(
      NotificationDirectOpen.pushNamed<void>(
        context,
        name,
        arguments: ticket.argumentsFor(name),
      ),
    );
    _opened = true;
  }

  void _showFailure() {
    if (!_current ||
        !_foreground ||
        _opened ||
        _terminal != null ||
        _error == null) {
      return;
    }
    NotificationDirectOpen.feedback(
      context,
      message: _error!,
      retry: () => unawaited(_open()),
      isCurrent: () => _current && _foreground && !_opened,
    );
  }

  @override
  Widget build(BuildContext context) {
    final terminal = _terminal;
    if (terminal == null || _terminalTicket == null) {
      return const SizedBox.shrink();
    }
    return NotificationDirectOpen.terminalFeedback(
      context,
      ticket: _terminalTicket!,
      message: 'Bu bildirimin hedefi artık kullanılamıyor.',
      contentIdentity: terminal,
    );
  }

  @override
  void dispose() {
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
