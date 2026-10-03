import '../notification_direct_open.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../profile/presentation/screens/media_detail_screen.dart';
import '../../data/notification_media_repository.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../data/notification_target_repository.dart';
import '../cubit/notification_cubit.dart';
import '../notification_target_read.dart';

/// Shared native/inbox entry. It resolves a fresh exact notification, then a
/// fresh authorized media target; only the destination's real content can acknowledge it.
class MediaNotificationOpenScreen extends StatefulWidget {
  const MediaNotificationOpenScreen({super.key, required this.target});
  final PushTarget target;
  @override
  State<MediaNotificationOpenScreen> createState() =>
      _MediaNotificationOpenScreenState();
}

class _MediaNotificationOpenScreenState
    extends State<MediaNotificationOpenScreen>
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
      final result = await _repository.resolveMedia(widget.target, _session);
      if (!_current ||
          !_foreground ||
          !result.isSuccess ||
          result.data == null) {
        return;
      }
      final item = result.data!;
      final response = await serviceLocator<NotificationMediaRepository>()
          .resolve(item.id, item.payload['targetId'] as String);
      if (!_current ||
          !_foreground ||
          !response.isSuccess ||
          response.data == null) {
        _error = 'Bu içerik şu anda kullanılamıyor.';
        return;
      }
      final media = response.data!;
      if (!mounted) return;
      final ticket = NotificationTargetRead.media(
        notification: item,
        cubit: serviceLocator<NotificationCubit>(),
        sessions: _sessions,
        repository: _repository,
        content: media,
      );
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
