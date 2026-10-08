import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../collab/domain/collab_repository.dart';
import '../../../collab/domain/entities/collab_job.dart';
import '../../../collab/presentation/collab_route_args.dart';
import '../../../collab/presentation/screens/collab_actor_reviews_screen.dart';
import '../../../collab/presentation/screens/collab_discovery_screen.dart';
import '../../../collab/presentation/screens/collab_incoming_applications_screen.dart';
import '../../../collab/presentation/screens/collab_listing_detail_screen.dart';
import '../../../collab/presentation/screens/collab_my_applications_screen.dart';
import '../../../collab/presentation/theme/collab_visual_theme.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import '../../../overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../../overthinking/presentation/screens/overthinking_manage_screen.dart';
import '../../data/notification_target_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notification_cubit.dart';
import '../notification_direct_open.dart';
import '../notification_target_read.dart';

/// Collab and Overthinking share their existing product pages, never a report
/// route or a discovery-to-detail hop. Collab native and inbox share this entry.
class InboxProductNotificationOpen extends StatefulWidget {
  const InboxProductNotificationOpen({super.key, required this.notification});
  InboxProductNotificationOpen.native({super.key, required PushTarget target})
    : notification = AppNotification(
        id: target.notificationId,
        recipientId: target.recipientId,
        type: target.type,
        title: '',
        message: '',
        read: false,
        createdAt: null,
        payload: const {},
      );
  final AppNotification notification;
  @override
  State<InboxProductNotificationOpen> createState() => _OpenState();
}

class _OpenState extends State<InboxProductNotificationOpen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<NotificationTargetRepository>();
  ModalRoute<dynamic>? _route;
  bool _initial = true, _busy = false, _opened = false;
  String? _error;
  bool get _current =>
      mounted &&
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      _session.isActive &&
      !_session.requiresListenerProfileChoice &&
      _session.userId == widget.notification.recipientId &&
      _route?.isCurrent == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    _session;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_open()));
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
    if (_initial) unawaited(_open());
    _feedback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_initial) unawaited(_open());
      _feedback();
    }
  }

  @override
  void dispose() {
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _feedback() {
    if (!_current || _opened || _error == null) return;
    NotificationDirectOpen.feedback(
      context,
      message: _error!,
      retry: () => unawaited(_open()),
      isCurrent: () => _current && !_opened,
      duration: const Duration(days: 1),
    );
  }

  Future<void> _open() async {
    if (!_current || _busy || _opened) return;
    _initial = false;
    _busy = true;
    _error = null;
    try {
      final result = await _repository.resolveInboxProduct(
        widget.notification,
        _session,
      );
      if (!_current || !result.isSuccess || result.data == null) return;
      final item = result.data!;
      if (item.type.startsWith('COLLAB_')) {
        await _collab(item);
      } else {
        await _overthinking(item);
      }
    } catch (_) {
      // A generic lookup/permission failure is never read evidence.
    } finally {
      _busy = false;
      if (!_opened) _error ??= 'Bu içerik şu anda kullanılamıyor.';
      _feedback();
    }
  }

  NotificationTargetRead _ticket(AppNotification item) =>
      NotificationTargetRead.venue(
        notification: item,
        cubit: serviceLocator<NotificationCubit>(),
        sessions: _sessions,
        repository: _repository,
      );
  void _push(
    AppNotification item,
    Widget destination, {
    bool collab = false,
    NotificationTargetRead? ticket,
  }) {
    if (!_current) return;
    final route = collab
        ? collabPageRoute<void>(context: context, builder: (_) => destination)
        : MaterialPageRoute<void>(
            // Overthinking's exact product owns its feedback. The app-wide
            // messenger also serves the origin/profile scaffolds and can paint
            // a retry there while it is absent from this returning destination.
            builder: (_) => ScaffoldMessenger(child: destination),
          );
    _opened = true;
    unawaited(
      NotificationDirectOpen.push<void>(
        context,
        (ticket ?? _ticket(item)).attach(route),
      ),
    );
  }

  Future<void> _collab(AppNotification item) async {
    final args = CollabDiscoveryRouteArgs.fromNotificationPayload(item.payload);
    final domain = serviceLocator<CollabRepository>();
    if (args.action == 'REPORT_RESOLVED') {
      final decision = item.payload['decision'];
      if (!PushTarget.isUuid(item.payload['reportId']) ||
          !const {'REMOVE_LISTING', 'DISMISS'}.contains(decision)) {
        return;
      }
      final ticket = NotificationTargetRead.content(
        notification: item,
        cubit: serviceLocator<NotificationCubit>(),
        sessions: _sessions,
        repository: _repository,
        content: item,
      );
      _push(
        item,
        NotificationTerminalFeedback(
          message: decision == 'REMOVE_LISTING'
              ? 'Bildirdiğin ilan kaldırıldı.'
              : 'Bildirimin incelendi.',
          contentIdentity: item,
          child: const CollabDiscoveryScreen(),
        ),
        collab: true,
        ticket: ticket,
      );
      return;
    }
    switch (args.target) {
      case CollabDeepLinkTarget.listing:
        final result = await domain.getListing(args.initialListingId!);
        if (!_current ||
            !result.isSuccess ||
            result.data?.id != args.initialListingId) {
          return;
        }
        _push(
          item,
          CollabListingDetailScreen(listingId: args.initialListingId!),
          collab: true,
        );
      case CollabDeepLinkTarget.incomingApplications:
        _push(
          item,
          CollabIncomingApplicationsScreen(
            listingId: args.initialListingId!,
            initialApplicationId: args.applicationId,
          ),
          collab: true,
        );
      case CollabDeepLinkTarget.myApplications:
      case CollabDeepLinkTarget.jobs:
        _push(
          item,
          CollabMyApplicationsScreen(
            initialSection: args.target == CollabDeepLinkTarget.myApplications
                ? CollabApplicationsSection.applications
                : CollabApplicationsSection.jobs,
            initialApplicationId: args.applicationId,
            initialJobId: args.jobId,
            initialAction: args.action,
          ),
          collab: true,
        );
      case CollabDeepLinkTarget.reviews:
        CollabJob? job;
        for (var page = 0; page < 100 && _current; page++) {
          final result = await domain.getMyJobs(page: page, size: 30);
          if (!_current || !result.isSuccess || result.data == null) return;
          job = result.data!.items.where((j) => j.id == args.jobId).firstOrNull;
          if (job != null || !result.data!.hasNext) break;
        }
        if (!_current || job == null) return;
        _push(
          item,
          CollabActorReviewsScreen(
            actor: job.listing.ownedByMe ? job.publisher : job.applicant,
            initialReviewId: args.reviewId,
          ),
          collab: true,
        );
      case CollabDeepLinkTarget.discovery:
        _error = 'Bu iş birliği içeriği şu anda kullanılamıyor.';
    }
  }

  Future<void> _overthinking(AppNotification item) async {
    final requestId = item.payload['revealRequestId'];
    if (!PushTarget.isUuid(requestId)) return;
    if (item.type != 'OVERTHINKING_REVEAL_REQUEST_APPROVED') {
      _push(
        item,
        OverthinkingManageScreen(
          initialTabIndex: item.type == 'OVERTHINKING_REVEAL_REQUEST_RECEIVED'
              ? 1
              : 2,
          initialRequestId: requestId as String,
          initialPostId: item.payload['postId'] as String,
          initialRequestStatus: item.payload['requestStatus'] as String,
          initialRecipientId: item.recipientId,
        ),
      );
      return;
    }
    final postId = item.payload['postId'];
    if (!PushTarget.isUuid(postId)) return;
    final result = await serviceLocator<OverthinkingRepository>().getDetail(
      postId: postId as String,
    );
    if (!_current ||
        !result.isSuccess ||
        result.data?.id != postId ||
        result.data?.hasVisibleAuthor != true) {
      return;
    }
    final post = result.data!;
    _push(
      item,
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => serviceLocator<OverthinkingFeedCubit>()),
          BlocProvider(
            create: (_) => serviceLocator<CommentThreadCubit>()
              ..load(
                targetType: OverthinkingFeedCubit.targetType,
                targetId: post.id,
              ),
          ),
        ],
        child: OverthinkingDetailScreen(
          post: post,
          revealRequesting: false,
          requireAuthorVisibility: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
