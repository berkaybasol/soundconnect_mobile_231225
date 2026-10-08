import '../../../notification/presentation/notification_direct_open.dart';
import '../../../notification/presentation/notification_target_read.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../domain/dm_repository.dart';
import 'dm_chat_screen.dart';

/// Resolves a push without opening the inbox or acknowledging any messages.
/// Read acknowledgement remains owned by the visible chat and its first frame.
class DmNotificationOpenScreen extends StatefulWidget {
  const DmNotificationOpenScreen({super.key, required this.target});

  final PushTarget target;

  @override
  State<DmNotificationOpenScreen> createState() =>
      _DmNotificationOpenScreenState();
}

class _DmNotificationOpenScreenState extends State<DmNotificationOpenScreen>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  static const _unavailable =
      'Sohbet şu anda açılamıyor. Biraz sonra tekrar deneyebilirsin.';

  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<DmRepository>();
  bool _initialAttemptPending = true;
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
      !_session.requiresListenerProfileChoice &&
      _session.userId == widget.target.recipientId &&
      NotificationDirectOpen.routeOf(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    // Capture the owner before another frame or session change can intervene.
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
  void didPopNext() => _showFailure();

  @override
  void dispose() {
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_initialAttemptPending) unawaited(_open());
      _showFailure();
    }
  }

  Future<void> _open() async {
    if (!mounted || _busy || _opened || !_foreground) return;
    _initialAttemptPending = false;
    final conversationId = widget.target.conversationId;
    if (!_current ||
        widget.target.type != 'DM_NEW_MESSAGE' ||
        !PushTarget.isUuid(widget.target.notificationId) ||
        !PushTarget.isUuid(widget.target.recipientId) ||
        !PushTarget.isUuid(conversationId)) {
      setState(() => _error = _unavailable);
      _showFailure();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Sender identity comes from the authenticated, current server projection.
      final result = await _repository.getConversationPreview(
        conversationId: conversationId!,
      );
      if (!mounted) return;
      final conversation = result.data;
      if (!_current ||
          !_foreground ||
          !result.isSuccess ||
          conversation == null ||
          conversation.conversationId != conversationId ||
          conversation.otherUserId.trim().isEmpty) {
        setState(() => _error = _unavailable);
        return;
      }
      _opened = true;
      unawaited(
        NotificationDirectOpen.pushNamed<void>(
          context,
          AppRoutes.dmChat,
          arguments: DmChatScreenArgs(
            otherUserId: conversation.otherUserId,
            otherUsername: conversation.otherUsername,
            otherUserProfilePicture: conversation.otherUserProfilePicture,
            currentUserId: _session.userId,
            conversationId: conversation.conversationId,
            otherUserVisibilityMode: conversation.otherUserVisibilityMode,
            otherUserDeleted: conversation.otherUserDeleted,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _opened = false;
        setState(() => _error = _unavailable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
