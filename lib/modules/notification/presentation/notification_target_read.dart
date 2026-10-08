import 'dart:async';
import 'dart:io' show Directory, File, FileMode;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../domain/entities/table_notification_target.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/push/push_provider.dart';
import '../data/notification_target_repository.dart';
import '../domain/entities/app_notification.dart';
import '../domain/notification_audience_policy.dart';
import 'cubit/notification_cubit.dart';
import 'notification_read_recovery.dart';
import '../../../shared/widgets/app_snack_bar.dart';

part 'notification_target_retry_snack.dart';

final notificationTargetRouteObserver = NotificationTargetRouteObserver();

// Opt-in local debug evidence for devices that suppress the Flutter log tag.
// Only exact IDs/state are recorded, never tokens, user text or HTTP bodies.
Future<void> _collabTraceWrite = Future<void>.value();
int _collabTraceLines = 0;
void _recordCollabTrace(String line) {
  debugPrint(line);
  if (!kDebugMode ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      !const bool.fromEnvironment('COLLAB_ACK_DIAGNOSTICS') ||
      _collabTraceLines++ >= 2048) {
    return;
  }
  _collabTraceWrite = _collabTraceWrite
      .then((_) async {
        final file = File(
          '${Directory.systemTemp.path}/collab-ack-recovery.log',
        );
        if (await file.exists() && await file.length() > 512 * 1024) return;
        await file.writeAsString(
          '${DateTime.now().toUtc().toIso8601String()} $line\n',
          mode: FileMode.append,
          flush: true,
        );
      })
      .catchError((Object _) {});
}

class NotificationTargetRouteObserver
    extends RouteObserver<ModalRoute<dynamic>> {
  ModalRoute<dynamic>? currentRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalRoute) currentRoute = route;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = previousRoute is ModalRoute ? previousRoute : null;
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is ModalRoute) currentRoute = newRoute;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(currentRoute, route)) {
      currentRoute = previousRoute is ModalRoute ? previousRoute : null;
    }
    super.didRemove(route, previousRoute);
  }
}

/// One notification selection, bound to its owner and exact destination.
/// Route creation and loading/error frames are deliberately not read receipts.
class NotificationTargetRead {
  NotificationTargetRead({
    required this.notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
  }) : _cubit = cubit,
       _sessions = sessions,
       _session = sessions.session;

  /// Native venue entry uses the captured-token endpoint and offers recovery
  /// only after the actual destination's successful content has been painted.
  NotificationTargetRead.venue({
    required this.notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
    required NotificationTargetRepository repository,
  }) : _cubit = cubit,
       _sessions = sessions,
       _session = sessions.session {
    _recovery = NotificationReadRecovery(
      isCurrent: () => isCurrent,
      acknowledge: () async =>
          (await repository.acknowledge(notification, _session)).isSuccess,
      confirm: () => _cubit.applyConfirmedExternalRead(notification, _session),
    );
  }

  factory NotificationTargetRead.follow({
    required AppNotification notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
    required NotificationTargetRepository repository,
    required String targetId,
    String? targetUserId,
  }) {
    return NotificationTargetRead.venue(
        notification: notification,
        cubit: cubit,
        sessions: sessions,
        repository: repository,
      )
      .._followTargetId = targetId
      .._followUserId = targetUserId;
  }

  factory NotificationTargetRead.table({
    required AppNotification notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
    required NotificationTargetRepository repository,
    required TableNotificationTarget content,
  }) => NotificationTargetRead.venue(
    notification: notification,
    cubit: cubit,
    sessions: sessions,
    repository: repository,
  ).._tableContent = content;

  TableNotificationTarget? _tableContent;
  String? _followTargetId;
  Object? _mediaContent;
  String? _customModule;

  factory NotificationTargetRead.module({
    required AppNotification notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
    required NotificationTargetRepository repository,
    required String kind,
    required Object content,
  }) => NotificationTargetRead.content(
    notification: notification,
    cubit: cubit,
    sessions: sessions,
    repository: repository,
    content: content,
  ).._customModule = kind;

  static bool isCustomModule(BuildContext context, String kind) =>
      _ticketFor(context)?._customModule == kind;

  factory NotificationTargetRead.content({
    required AppNotification notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
    required NotificationTargetRepository repository,
    required Object content,
  }) => NotificationTargetRead.venue(
    notification: notification,
    cubit: cubit,
    sessions: sessions,
    repository: repository,
  ).._mediaContent = content;

  factory NotificationTargetRead.media({
    required AppNotification notification,
    required NotificationCubit cubit,
    required AuthSessionManager sessions,
    required NotificationTargetRepository repository,
    required Object content,
  }) => NotificationTargetRead.venue(
    notification: notification,
    cubit: cubit,
    sessions: sessions,
    repository: repository,
  ).._mediaContent = content;
  String? _followUserId;
  Object? _followContent;
  Object? _followRequest;

  /// Issued only when this destination starts its own real content request.
  /// The completion binds the exact returned object, target and account; a
  /// cached state or a different request cannot acknowledge this notification.
  static bool Function(Object, String, String?)? beginFollowRequest(
    BuildContext context,
  ) {
    final route = ModalRoute.of(context);
    final ticket = route == null ? null : _tickets[route];
    if (ticket?._followTargetId == null) return null;
    final request = Object();
    ticket!._followRequest = request;
    ticket._followContent = null;
    return (content, id, userId) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final valid =
          context.mounted &&
          ticket.isCurrent &&
          identical(ticket._destination, route) &&
          route!.isActive &&
          route.isCurrent &&
          identical(ticket._followRequest, request) &&
          id == ticket._followTargetId &&
          (ticket._followUserId == null || userId == ticket._followUserId) &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed);
      if (valid) ticket._followContent = content;
      return valid;
    };
  }

  /// A removed-membership target is ready only when its fresh active list no
  /// longer contains that exact band. Rejoining does not read an old removal.
  static bool bandRemovalReady(
    BuildContext context,
    Iterable<String> activeBandIds,
  ) {
    final route = ModalRoute.of(context);
    final ticket = route == null ? null : _tickets[route];
    if (ticket?.notification.type != 'BAND_MEMBER_REMOVED') return true;
    final id = ticket!.notification.payload['bandId'];
    return PushTarget.isUuid(id) && !activeBandIds.contains(id);
  }

  /// A loaded list is not read evidence. Its fresh, visible row must match the
  /// exact identity carried by the notification already attached to this route.
  static bool artistVenueRequestReady(BuildContext context, String requestId) {
    final ticket = _ticketFor(context);
    return ticket?.notification.type ==
            'ARTIST_VENUE_LINK_APPLICATION_REQUEST' &&
        ticket?.notification.payload['module'] == 'ARTIST_VENUE' &&
        ticket?.notification.payload['action'] == 'REQUEST_CREATED' &&
        _matchesListTarget(ticket, 'requestId', requestId);
  }

  static bool eventPerformerRequestReady(
    BuildContext context, {
    required String requestId,
    required String eventId,
  }) {
    final ticket = _ticketFor(context);
    return ticket?.notification.type == 'EVENT_PERFORMER_APPROVAL_REQUESTED' &&
        ticket?.notification.payload['module'] == 'EVENT_PERFORMER' &&
        _matchesListTarget(ticket, 'requestId', requestId) &&
        _matchesListTarget(ticket, 'eventId', eventId);
  }

  static bool eventPlanReady(BuildContext context, String planId) {
    final ticket = _ticketFor(context);
    return ticket?.notification.type == 'EVENT_PERFORMER_APPROVAL_REQUESTED' &&
        ticket?.notification.payload['module'] == 'EVENT_PLAN' &&
        _matchesListTarget(ticket, 'planId', planId);
  }

  static NotificationTargetRead? _ticketFor(BuildContext context) {
    final route = ModalRoute.of(context);
    return route == null ? null : _tickets[route];
  }

  static bool _matchesListTarget(
    NotificationTargetRead? ticket,
    String key,
    String id,
  ) {
    final expected = ticket?.notification.payload[key];
    return ticket?.isCurrent == true &&
        PushTarget.isUuid(expected) &&
        expected == id;
  }

  static Widget bandRemovalResult(
    BuildContext context, {
    required bool ready,
    required Widget child,
  }) {
    final route = ModalRoute.of(context);
    final ticket = route == null ? null : _tickets[route];
    if (ticket?.notification.type != 'BAND_MEMBER_REMOVED') {
      return NotificationTargetReady(ready: ready, child: child);
    }
    // The fresh exact notification and fresh membership absence are both
    // required. A generic loaded list alone is not a terminal result.
    ticket!._mediaContent ??= ticket.notification;
    return NotificationTerminalFeedback(
      message: 'Bu gruptan çıkarıldın.',
      contentIdentity: ticket._mediaContent,
      ready: ready,
      child: child,
    );
  }

  static final _tickets = Expando<NotificationTargetRead>();
  final AppNotification notification;
  final NotificationCubit _cubit;
  final AuthSessionManager _sessions;
  final AuthSession _session;
  Route<dynamic>? _destination;
  bool _attempted = false;
  NotificationReadRecovery? _recovery;

  bool get isCurrent =>
      !_cubit.isClosed &&
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      ((_followTargetId == null &&
              _mediaContent == null &&
              !PushTarget.collabTypes.contains(notification.type) &&
              !PushTarget.overthinkingTypes.contains(notification.type) &&
              !PushTarget.bandTypes.contains(notification.type)) ||
          _session.expiresAt?.isAfter(DateTime.now()) == true) &&
      (_session.isActive ||
          (_session.isVenueApplicationSession &&
              PushTarget.venueApplicationTypes.contains(notification.type))) &&
      !_session.requiresListenerProfileChoice &&
      _session.userId == notification.recipientId.trim() &&
      (!_session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) ||
          NotificationAudiencePolicy.visibleToListener(notification.type));

  Route<T> attach<T>(Route<T> route) {
    if (!isCurrent || _attempted || (_recovery?.attempted ?? false)) {
      return route;
    }
    _destination = route;
    _tickets[route] = this;
    unawaited(
      route.popped.then((_) {
        if (identical(_destination, route)) _destination = null;
      }),
    );
    return route;
  }

  NotificationReadArguments argumentsFor(String name, {Object? arguments}) =>
      NotificationReadArguments(this, name, arguments);

  /// Only use for an automatic hop to the same verified notification target.
  /// Arbitrary links clicked later in a destination must not inherit its ticket.
  static Route<T> transfer<T>(BuildContext context, Route<T> route) {
    final origin = ModalRoute.of(context);
    final ticket = origin == null ? null : _tickets[origin];
    if (ticket == null || !identical(ticket._destination, origin)) return route;
    return ticket.attach(route);
  }

  static Object? forwardNamed(
    BuildContext context,
    String name, {
    Object? arguments,
  }) {
    final origin = ModalRoute.of(context);
    final ticket = origin == null ? null : _tickets[origin];
    if (ticket == null || !identical(ticket._destination, origin)) {
      return arguments;
    }
    return ticket.argumentsFor(name, arguments: arguments);
  }

  void _presented(Route<dynamic> route, Object owner, bool Function() visible) {
    if ((TableNotificationTarget.actions.containsKey(notification.type) &&
            _tableContent == null) ||
        _attempted ||
        notification.read ||
        !isCurrent ||
        !identical(_destination, route) ||
        !route.isCurrent) {
      return;
    }
    final recovery = _recovery;
    if (recovery != null) {
      recovery.present(owner, visible);
      return;
    }
    _attempted = true;
    // The cubit mutates counts and reconciles OS cards only after server success.
    // Failure remains unread; a later deliberate inbox selection can retry.
    unawaited(_acknowledge());
  }

  Future<void> _acknowledge() async {
    try {
      await _cubit.markAsRead(notification);
    } catch (_) {
      // A transport failure must not dismiss a successfully opened destination.
      // No optimistic read or retry on unrelated rebuild/resume is performed.
    }
  }
}

/// The router unwraps the normal arguments before building the destination.
/// Redirected or unavailable routes never receive the original read ticket.
class NotificationReadArguments {
  const NotificationReadArguments(this.ticket, this.routeName, this.arguments);
  final NotificationTargetRead ticket;
  final String routeName;
  final Object? arguments;
}

/// A fresh, verified terminal result shown on an existing product page.
/// Enqueuing a SnackBar is not read evidence: only its actual painted content,
/// on the exact foreground destination and captured session, may acknowledge.
class NotificationTerminalFeedback extends StatefulWidget {
  const NotificationTerminalFeedback({
    super.key,
    required this.message,
    required this.child,
    this.contentIdentity,
    this.acknowledge = true,
    this.retry,
    this.ready = true,
  }) : _origin = null,
       _originContext = null,
       _readTicket = null,
       _originCurrent = null,
       _onPresented = null;

  const NotificationTerminalFeedback.onOrigin({
    super.key,
    required this.message,
    required this.contentIdentity,
    required NotificationTargetRead readTicket,
    required ModalRoute<dynamic> origin,
    required BuildContext originContext,
    required bool Function() isCurrent,
    required VoidCallback onPresented,
  }) : child = const SizedBox.shrink(),
       acknowledge = true,
       retry = null,
       ready = true,
       _origin = origin,
       _originContext = originContext,
       _readTicket = readTicket,
       _originCurrent = isCurrent,
       _onPresented = onPresented;
  final String message;
  final Widget child;
  final Object? contentIdentity;
  final bool acknowledge;
  final VoidCallback? retry;
  final bool ready;
  final ModalRoute<dynamic>? _origin;
  final BuildContext? _originContext;
  final NotificationTargetRead? _readTicket;
  final bool Function()? _originCurrent;
  final VoidCallback? _onPresented;
  @override
  State<NotificationTerminalFeedback> createState() =>
      _NotificationTerminalFeedbackState();
}

class _NotificationTerminalFeedbackState
    extends State<NotificationTerminalFeedback>
    with WidgetsBindingObserver, RouteAware {
  BuildContext? _messageContext;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Animation<double>? _messageAnimation;
  ModalRoute<dynamic>? _route;
  NotificationTargetRead? _ticket;
  _TargetRetrySnack? _originSnack;
  String? _originSnackMessage;
  bool _scheduled = false,
      _shown = false,
      _painted = false,
      _retryShown = false;
  bool _resultPresented = false;
  bool get _current {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return mounted &&
        widget.ready &&
        widget._originCurrent?.call() != false &&
        _route?.isCurrent == true &&
        _route?.isActive == true &&
        (_route?.animation == null ||
            _route!.animation!.status == AnimationStatus.completed) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        (!widget.acknowledge ||
            (_ticket?.isCurrent == true &&
                identical(_ticket?._destination, _route)));
  }

  bool get _visible {
    if (!_current ||
        !_painted ||
        _messageAnimation?.status != AnimationStatus.completed) {
      return false;
    }
    final box = _messageContext?.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return false;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final messageContext = _messageContext!;
    final scaffold = Scaffold.maybeOf(
      messageContext,
    )?.context.findRenderObject();
    final viewport = scaffold is RenderBox && scaffold.hasSize
        ? scaffold.localToGlobal(Offset.zero) & scaffold.size
        : Offset.zero & MediaQuery.sizeOf(messageContext);
    return viewport.contains(rect.topLeft) &&
        viewport.inflate(.5).contains(rect.bottomRight);
  }

  bool get _readVisible => _current && _resultPresented;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = widget._origin ?? ModalRoute.of(context);
    if (!identical(route, _route)) {
      _unbind();
      _route = route;
      _ticket =
          widget._readTicket ??
          (route == null ? null : NotificationTargetRead._tickets[route]);
      // Keep an origin-only ticket local; do not overwrite a real destination's
      // ticket in the route registry or let unrelated content acknowledge it.
      if (widget._origin != null) _ticket?._destination = route;
      if (route != null) {
        notificationTargetRouteObserver.subscribe(this, route);
        route.animation?.addStatusListener(_animation);
      }
      _ticket?._sessions.addListener(_schedule);
      _ticket?._recovery?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(NotificationTerminalFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        !identical(oldWidget.contentIdentity, widget.contentIdentity)) {
      _hide();
      _shown = false;
      _resultPresented = false;
    }
    _schedule();
  }

  void _animation(AnimationStatus status) => _schedule();
  @override
  void didPush() => _schedule();
  @override
  void didPopNext() => _schedule();
  @override
  void didPushNext() => _suspend();
  @override
  void didPop() => _suspend();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      _suspend();
    }
  }

  void _suspend() {
    _ticket?._recovery?.suspend(this);
    if (!_resultPresented || (!widget.acknowledge && widget.retry != null)) {
      _shown = false;
    }
    _hide();
  }

  void _hide() {
    _messageAnimation?.removeStatusListener(_animation);
    _messageAnimation = null;
    _painted = false;
    _retryShown = false;
    if (widget._origin != null) {
      final snack = _originSnack;
      if (snack?.painted == true) _originSnack = null;
      snack?.retire();
    } else {
      _messengerKey.currentState?.removeCurrentSnackBar();
    }
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final animation = _messageContext
          ?.findAncestorWidgetOfExactType<SnackBar>()
          ?.animation;
      if (!identical(animation, _messageAnimation)) {
        _messageAnimation?.removeStatusListener(_animation);
        _messageAnimation = animation;
        animation?.addStatusListener(_animation);
      }
      if (!_current) {
        _suspend();
        return;
      }
      final recovery = _ticket?._recovery;
      if (!_shown) {
        _shown = true;
        _show(widget.message, widget.retry);
      }
      if (widget.acknowledge &&
          !_retryShown &&
          _visible &&
          widget.contentIdentity != null &&
          ((_ticket?._tableContent != null &&
                  identical(_ticket?._tableContent, widget.contentIdentity)) ||
              (_ticket?._mediaContent != null &&
                  identical(_ticket?._mediaContent, widget.contentIdentity)))) {
        if (!_resultPresented) {
          _resultPresented = true;
          widget._onPresented?.call();
        }
      }
      if (widget.acknowledge && _readVisible) {
        _ticket?._presented(_route!, this, () => _readVisible);
      }
      if (recovery?.showsRetryFor(this) == true &&
          !_retryShown &&
          !recovery!.busy) {
        _retryShown = true;
        _hide();
        _retryShown = true;
        _show('Okundu bilgisi kaydedilemedi.', () {
          _retryShown = false;
          if (_readVisible) recovery.retry(this);
        });
      } else if (_retryShown &&
          recovery != null &&
          !recovery.busy &&
          !recovery.showsRetryFor(this)) {
        _hide();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _show(String message, VoidCallback? retry) {
    final originContext = widget._originContext;
    final messenger = originContext == null
        ? _messengerKey.currentState
        : originContext.mounted
        ? ScaffoldMessenger.maybeOf(originContext)
        : null;
    if (messenger == null) return;
    if (originContext != null &&
        _originSnack != null &&
        !_originSnack!.painted &&
        !_originSnack!.closed &&
        _originSnackMessage == message) {
      _originSnack!.retired = false;
      return;
    }
    _messageContext = null;
    final snack = originContext == null ? null : _TargetRetrySnack(messenger);
    if (snack != null) {
      _originSnack = snack;
      _originSnackMessage = message;
    }
    final controller = messenger.showSnackBar(
      appSnackBar(
        originContext ?? context,
        // A shared messenger can render one bar in more than one Scaffold.
        // Capture only this origin's content; a GlobalKey here would be reused
        // across those Scaffolds and an offstage copy is never read evidence.
        content: _TerminalFeedbackContent(
          message: message,
          onBuild: (messageContext) {
            if (identical(ModalRoute.of(messageContext), _route)) {
              _messageContext = messageContext;
            }
          },
          onDeactivate: (messageContext) {
            if (identical(_messageContext, messageContext)) {
              _messageContext = null;
            }
          },
        ),
        tone: AppSnackBarTone.info,
        inlineAction: true,
        duration:
            retry != null &&
                (_ticket?.notification.type.startsWith('COLLAB_') == true ||
                    PushTarget.overthinkingTypes.contains(
                      _ticket?.notification.type,
                    ))
            ? const Duration(days: 1)
            : const Duration(seconds: 5),
        onVisible: () {
          if (snack != null) {
            snack.painted = true;
            if (snack.retired ||
                !mounted ||
                !identical(_originSnack, snack) ||
                !_current) {
              snack.retire();
              return;
            }
          }
          if (!mounted) return;
          _painted = true;
          _schedule();
        },
        action: retry == null
            ? null
            : SnackBarAction(
                label: 'Tekrar dene',
                onPressed: () {
                  if (!_current) return;
                  retry();
                },
              ),
      ),
    );
    if (snack != null) {
      snack.controller = controller;
      unawaited(
        controller.closed.then((_) {
          snack.closed = true;
          if (identical(_originSnack, snack)) _originSnack = null;
        }),
      );
    }
  }

  void _unbind() {
    _ticket?._recovery?.suspend(this);
    _ticket?._sessions.removeListener(_schedule);
    _ticket?._recovery?.removeListener(_schedule);
    _route?.animation?.removeStatusListener(_animation);
    if (widget._origin != null && identical(_ticket?._destination, _route)) {
      _ticket?._destination = null;
    }
    notificationTargetRouteObserver.unsubscribe(this);
  }

  @override
  void dispose() {
    _hide();
    _unbind();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._origin != null
      ? widget.child
      : ScaffoldMessenger(key: _messengerKey, child: widget.child);
}

// A shared messenger may mount the same content in several Scaffolds. Track
// each copy's lifetime so read checks never retain a deactivated context.
class _TerminalFeedbackContent extends StatefulWidget {
  const _TerminalFeedbackContent({
    required this.message,
    required this.onBuild,
    required this.onDeactivate,
  });
  final String message;
  final ValueChanged<BuildContext> onBuild;
  final ValueChanged<BuildContext> onDeactivate;
  @override
  State<_TerminalFeedbackContent> createState() =>
      _TerminalFeedbackContentState();
}

class _TerminalFeedbackContentState extends State<_TerminalFeedbackContent> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(context);
    return Text(widget.message);
  }

  @override
  void deactivate() {
    widget.onDeactivate(context);
    super.deactivate();
  }
}

/// Place around successfully loaded, authorized target content, never around
/// its spinner, error, intermediate routing screen, or unrelated fallback.
/// In normal navigation (without a read ticket) this widget has no side effect.
class NotificationTargetReady extends StatefulWidget {
  const NotificationTargetReady({
    super.key,
    required this.child,
    this.ready = true,
    this.contentIdentity,
    this.requireVisibleBounds = false,
    this.allowPartialVisibility = false,
    this.onVisible,
    this.acknowledge = true,
    this.customModuleKinds = const {},
  });

  final Widget child;
  final bool ready;
  final Object? contentIdentity;
  final bool requireVisibleBounds;

  /// Long list cards can exceed the viewport. Require a meaningful visible
  /// portion (48 logical pixels), rather than making those cards unreadable.
  /// Other targets retain their existing full-bounds requirement.
  final bool allowPartialVisibility;
  final VoidCallback? onVisible;
  final bool acknowledge;

  /// A module campaign names the whole product surface. Only that surface's
  /// successful content presenter may consume its fresh destination proof.
  final Set<String> customModuleKinds;

  @override
  State<NotificationTargetReady> createState() =>
      _NotificationTargetReadyState();
}

class _NotificationTargetReadyState extends State<NotificationTargetReady>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  NotificationTargetRead? _ticket;
  _TargetRetrySnack? _retrySnack;
  bool _scheduled = false;
  bool _visibleCallbackSent = false;
  ScrollPosition? _scrollPosition;
  bool? _lastVisible;
  bool _viewportDirty = false;

  void _trace(String event) {
    if (!kDebugMode ||
        (_ticket?.notification.type.startsWith('COLLAB_') != true &&
            !(const bool.fromEnvironment('COLLAB_ACK_DIAGNOSTICS') &&
                PushTarget.overthinkingTypes.contains(
                  _ticket?.notification.type,
                )))) {
      return;
    }
    if (!widget.ready && _lastVisible != true && _retrySnack == null) return;
    _recordCollabTrace(
      'COLLAB_ACK_RECOVERY event=$event notification=${_ticket!.notification.id} '
      'owner=${identityHashCode(this)} route=${identityHashCode(_route)} '
      'content=${identityHashCode(widget.contentIdentity)} routeCurrent=${_route?.isCurrent} '
      'current=${_ticket!.isCurrent} ready=${widget.ready} '
      'scroll=${_scrollPosition?.hasPixels == true ? _scrollPosition!.pixels : null} '
      'lifecycle=${WidgetsBinding.instance.lifecycleState?.name}',
    );
  }

  bool get _visible {
    if (!mounted ||
        !widget.ready ||
        _viewportDirty ||
        !TickerMode.of(context)) {
      return false;
    }
    if (widget.requireVisibleBounds) {
      final box = context.findRenderObject();
      if (box is! RenderBox ||
          !box.attached ||
          !box.hasSize ||
          box.size.isEmpty) {
        return false;
      }
      final rect = box.localToGlobal(Offset.zero) & box.size;
      var visible = Offset.zero & MediaQuery.sizeOf(context);
      RenderObject? ancestor = box.parent;
      while (ancestor != null) {
        if (ancestor is RenderBox &&
            ancestor is RenderAbstractViewport &&
            ancestor.hasSize) {
          visible = visible.intersect(
            ancestor.localToGlobal(Offset.zero) & ancestor.size,
          );
        }
        ancestor = ancestor.parent;
      }
      if (visible.isEmpty) return false;
      if (widget.allowPartialVisibility) {
        final intersection = visible.intersect(rect);
        if (intersection.isEmpty ||
            intersection.height < math.min(48, rect.height) ||
            intersection.width < math.min(48, rect.width)) {
          return false;
        }
      } else if (!visible.contains(rect.topLeft) ||
          !visible.inflate(0.5).contains(rect.bottomRight)) {
        return false;
      }
    }
    final route = _route;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return route != null &&
        route.isCurrent &&
        route.isActive &&
        identical(_ticket?._destination, route) &&
        _ticket?.isCurrent == true &&
        (_ticket?._tableContent == null ||
            identical(_ticket?._tableContent, widget.contentIdentity)) &&
        (_ticket?._mediaContent == null ||
            identical(_ticket?._mediaContent, widget.contentIdentity) ||
            (_ticket?._customModule != null &&
                widget.customModuleKinds.contains(_ticket!._customModule))) &&
        (_ticket?._followTargetId == null ||
            (widget.contentIdentity != null &&
                identical(_ticket?._followContent, widget.contentIdentity))) &&
        (route.animation == null ||
            route.animation!.status == AnimationStatus.completed) &&
        (!PushTarget.overthinkingTypes.contains(_ticket?.notification.type) ||
            route.secondaryAnimation == null ||
            route.secondaryAnimation!.status == AnimationStatus.dismissed) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_retrySnack != null &&
        !identical(
          _retrySnack!.messenger,
          ScaffoldMessenger.maybeOf(context),
        )) {
      _hideRetry();
      _retrySnack = null;
      _trace('messenger_changed');
    }
    _bindScrollPosition();
    final route = ModalRoute.of(context);
    if (!identical(_route, route)) {
      _unbind();
      notificationTargetRouteObserver.unsubscribe(this);
      _route?.animation?.removeStatusListener(_animationChanged);
      _route?.secondaryAnimation?.removeStatusListener(_coverAnimationChanged);
      _route = route;
      _ticket = route == null ? null : NotificationTargetRead._tickets[route];
      if (_ticket?._recovery != null) {
        _ticket!._sessions.addListener(_sessionChanged);
        _ticket!._recovery!.addListener(_schedule);
      }
      if (route != null) {
        notificationTargetRouteObserver.subscribe(this, route);
        route.animation?.addStatusListener(_animationChanged);
        route.secondaryAnimation?.addStatusListener(_coverAnimationChanged);
      }
    }
    if (!_visible) _ticket?._recovery?.suspend(this);
    _schedule();
  }

  @override
  void didUpdateWidget(NotificationTargetReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindScrollPosition();
    if (!widget.ready ||
        !identical(oldWidget.contentIdentity, widget.contentIdentity)) {
      _suspend();
    }
    _schedule();
  }

  void _bindScrollPosition() {
    final position = widget.requireVisibleBounds
        ? Scrollable.maybeOf(context)?.position
        : null;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_scrollChanged);
    _scrollPosition = position;
    position?.addListener(_scrollChanged);
  }

  void _scrollChanged() {
    // Sliver paint offsets still describe the previous layout at this point.
    // Do not authorize an action/response until the new viewport is painted.
    // An in-flight response is fenced even for hide + return in one frame.
    _viewportDirty = true;
    if (_ticket?._recovery?.busy == true) _suspend();
    _schedule();
  }

  void _animationChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _schedule();
  }

  void _coverAnimationChanged(AnimationStatus status) {
    if (!PushTarget.overthinkingTypes.contains(_ticket?.notification.type)) {
      return;
    }
    // didPopNext runs before the covering product's reverse transition ends.
    // Wait for the exact destination to be fully uncovered before presenting
    // recovery again or accepting an action/late response from that content.
    if (status == AnimationStatus.dismissed) {
      _schedule();
    } else {
      _suspend();
    }
  }

  @override
  void didPush() => _schedule();

  @override
  void didPopNext() => _schedule();

  @override
  void didPushNext() => _suspend();

  @override
  void didPop() => _suspend();

  void _suspend() {
    _hideRetry();
    _ticket?._recovery?.suspend(this);
    _schedule();
  }

  void _sessionChanged() {
    _trace('session_changed');
    if (_ticket?.isCurrent != true) _suspend();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _trace('lifecycle_${state.name}');
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      // Paused apps may not schedule another frame. Hide synchronously in the
      // lifecycle callback instead of waiting for a post-frame UI update.
      _hideRetry();
      _suspend();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _viewportDirty = false;
      final recovery = _ticket?._recovery;
      final visible = _visible;
      if (_lastVisible != visible) {
        _lastVisible = visible;
        _trace('visible_$visible');
      }
      if (visible) {
        if (!_visibleCallbackSent && widget.onVisible != null) {
          _visibleCallbackSent = true;
          widget.onVisible!();
        }
        if (widget.acknowledge) {
          _ticket?._presented(_route!, this, () => _visible);
        }
      } else {
        recovery?.suspend(this);
      }
      if (recovery != null) {
        if (visible && recovery.showsRetryFor(this) && !recovery.busy) {
          _showRetry(recovery);
        } else {
          _hideRetry();
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _hideRetry();
    _scrollPosition?.removeListener(_scrollChanged);
    _trace('dispose');
    _unbind();
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _route?.animation?.removeStatusListener(_animationChanged);
    _route?.secondaryAnimation?.removeStatusListener(_coverAnimationChanged);
    super.dispose();
  }

  void _unbind() {
    final ticket = _ticket;
    if (ticket?._recovery == null) return;
    ticket!._recovery!.suspend(this);
    ticket._recovery!.removeListener(_schedule);
    ticket._sessions.removeListener(_sessionChanged);
  }

  void _hideRetry() {
    final snack = _retrySnack;
    // Keep an unpainted queued controller: repeated hide/return must not add
    // another queued retry. It can be reactivated for this same exact owner.
    if (snack?.painted == true) _retrySnack = null;
    snack?.retire();
  }

  void _showRetry(NotificationReadRecovery recovery) {
    if (_retrySnack != null) {
      if (!_retrySnack!.painted && !_retrySnack!.closed) {
        _retrySnack!.retired = false;
      }
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final snack = _TargetRetrySnack(messenger);
    _retrySnack = snack;
    _trace('retry_show');
    snack.controller = messenger.showSnackBar(
      appSnackBar(
        context,
        content: const Text('Okundu bilgisi kaydedilemedi.'),
        duration:
            _ticket?.notification.type.startsWith('COLLAB_') == true ||
                PushTarget.overthinkingTypes.contains(
                  _ticket?.notification.type,
                )
            ? const Duration(days: 1)
            : const Duration(seconds: 4),
        tone: AppSnackBarTone.info,
        inlineAction: true,
        onVisible: () {
          snack.painted = true;
          _trace('retry_painted');
          if (snack.retired ||
              !mounted ||
              !identical(_retrySnack, snack) ||
              !_visible) {
            snack.retire();
          }
        },
        action: SnackBarAction(
          label: 'Tekrar dene',
          onPressed: () {
            if (!identical(_retrySnack, snack) || !_visible) return;
            _trace('explicit_retry');
            _hideRetry();
            recovery.retry(this);
          },
        ),
      ),
    );
    unawaited(
      snack.controller.closed.then((reason) {
        snack.closed = true;
        _trace('retry_closed_${reason.name}');
        // A retired controller can complete after a newer message was shown.
        // It must never clear that message or send an ACK.
        if (!identical(_retrySnack, snack)) return;
        _retrySnack = null;
        if (mounted &&
            (_ticket?.notification.type.startsWith('COLLAB_') == true ||
                PushTarget.overthinkingTypes.contains(
                  _ticket?.notification.type,
                ))) {
          _schedule();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
