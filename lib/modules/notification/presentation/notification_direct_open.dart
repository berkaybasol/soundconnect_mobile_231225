import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_snack_bar.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import 'notification_target_read.dart';

/// Resolves a notification on the current product page, without adding a route.
/// Only a real destination is pushed. A second selection disposes the old work;
/// its mounted/session checks then fence late responses.
abstract final class NotificationDirectOpen {
  static final _active = Expando<_Opening>();

  static Future<void> start(
    BuildContext context, {
    required String identity,
    required WidgetBuilder builder,
    bool replaceOrigin = false,
  }) {
    final navigator = Navigator.of(context);
    final origin = ModalRoute.of(context) ??
        notificationTargetRouteObserver.currentRoute;
    final originContext = origin?.subtreeContext;
    if (origin == null || originContext == null || !origin.isCurrent) {
      return Future.value();
    }
    final previous = _active[navigator];
    if (previous?.identity == identity && previous?.origin == origin &&
        previous?.done.isCompleted == false) {
      return previous!.done.future;
    }
    previous?.finish();
    final sessions = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>() : null;
    final opening = _Opening(
      navigator, origin, originContext, identity, replaceOrigin,
      sessions, sessions?.session,
    );
    _active[navigator] = opening;
    final weakOpening = WeakReference(opening);
    unawaited(origin.popped.then((_) => weakOpening.target?.finish()));
    opening.entry = OverlayEntry(
      builder: (_) => _OpenScope(
        opening: opening,
        child: _OpenLifetime(opening: opening, builder: builder),
      ),
    );
    navigator.overlay!.insert(opening.entry!);
    return opening.done.future;
  }

  static ModalRoute<dynamic>? routeOf(BuildContext context) =>
      _OpenScope.maybeOf(context)?.origin ?? ModalRoute.of(context);

  static Future<T?> push<T>(BuildContext context, Route<T> route) {
    final opening = _OpenScope.maybeOf(context);
    if (opening == null) return Navigator.of(context).pushReplacement(route);
    if (!opening.visible) return Future.value();
    final result = opening.replaceOrigin
        ? opening.navigator.pushReplacement<T, void>(route)
        : opening.navigator.push<T>(route);
    opening.finish();
    return result;
  }

  static Future<T?> pushNamed<T>(
    BuildContext context,
    String name, {
    Object? arguments,
  }) {
    final opening = _OpenScope.maybeOf(context);
    if (opening == null) {
      return Navigator.of(context).pushReplacementNamed(name, arguments: arguments);
    }
    if (!opening.visible) return Future.value();
    final result = opening.replaceOrigin
        ? opening.navigator.pushReplacementNamed<T, void>(name, arguments: arguments)
        : opening.navigator.pushNamed<T>(name, arguments: arguments);
    opening.finish();
    return result;
  }

  static void feedback(
    BuildContext context, {
    required String message,
    VoidCallback? retry,
    bool Function()? isCurrent,
    Duration duration = const Duration(seconds: 4),
  }) {
    final opening = _OpenScope.maybeOf(context);
    if (opening != null) {
      opening.feedback(message, retry, isCurrent, duration);
      return;
    }
    // Standalone test/legacy callers still use the same small product feedback.
    if (!context.mounted || isCurrent?.call() == false) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(appSnackBar(
      context,
      content: Text(message),
      tone: AppSnackBarTone.info,
      inlineAction: true,
      duration: duration,
      action: retry == null ? null : SnackBarAction(label: 'Tekrar dene', onPressed: retry),
    ));
  }
}

class _Opening {
  _Opening(this.navigator, this.origin, this.context, this.identity, this.replaceOrigin,
      this.sessions, this.session);
  final NavigatorState navigator;
  final ModalRoute<dynamic> origin;
  final BuildContext context;
  final String identity;
  final bool replaceOrigin;
  final AuthSessionManager? sessions;
  final AuthSession? session;
  var done = Completer<void>();
  OverlayEntry? entry;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snack;
  String? message;
  VoidCallback? retryAction;
  bool Function()? sessionCurrent;
  Duration feedbackDuration = const Duration(seconds: 4);
  bool finished = false;

  bool get sessionMatches => sessions == null || identical(sessions!.session, session);
  bool get visible => !finished && sessionMatches && context.mounted && origin.isActive &&
      origin.isCurrent && (WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void feedback(String value, VoidCallback? retry, bool Function()? isCurrent,
      Duration duration) {
    if (!visible || isCurrent?.call() == false || message == value) return;
    message = value;
    retryAction = retry;
    sessionCurrent = isCurrent;
    feedbackDuration = duration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!visible || isCurrent?.call() == false || message != value) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
      messenger?.removeCurrentSnackBar();
      snack = messenger?.showSnackBar(appSnackBar(
        context,
        content: Text(value),
        tone: AppSnackBarTone.info,
        inlineAction: true,
        duration: duration,
        action: retry == null ? null : SnackBarAction(
          label: 'Tekrar dene',
          onPressed: () {
            if (!visible || isCurrent?.call() == false || !done.isCompleted) return;
            // The previous failure released its caller. An explicit retry is
            // a new flight that same-row/native selections must now share.
            done = Completer<void>();
            message = null;
            retry();
          },
        ),
      ));
      final shown = snack;
      shown?.closed.then((_) { if (identical(snack, shown)) snack = null; });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    // A failed request is finished for caller locks, but its explicit retry
    // remains mounted on this page until a new selection/navigation disposes it.
    if (!done.isCompleted) done.complete();
  }

  void hideFeedback() {
    if (navigator.mounted && context.mounted) snack?.close();
    snack = null;
  }

  void restoreFeedback() {
    final pending = message;
    if (pending == null || snack != null || !visible || sessionCurrent?.call() == false) return;
    message = null;
    feedback(pending, retryAction, sessionCurrent, feedbackDuration);
  }

  void finish() {
    if (finished) return;
    finished = true;
    hideFeedback();
    entry?.remove();
    entry?.dispose();
    entry = null;
    if (identical(NotificationDirectOpen._active[navigator], this)) {
      NotificationDirectOpen._active[navigator] = null;
    }
    if (!done.isCompleted) done.complete();
  }
}

class _OpenScope extends InheritedWidget {
  const _OpenScope({required this.opening, required super.child});
  final _Opening opening;
  static _Opening? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OpenScope>()?.opening;
  @override
  bool updateShouldNotify(_OpenScope oldWidget) => oldWidget.opening != opening;
}

class _OpenLifetime extends StatefulWidget {
  const _OpenLifetime({required this.opening, required this.builder});
  final _Opening opening;
  final WidgetBuilder builder;
  @override
  State<_OpenLifetime> createState() => _OpenLifetimeState();
}

class _OpenLifetimeState extends State<_OpenLifetime>
    with RouteAware, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    notificationTargetRouteObserver.subscribe(this, widget.opening.origin);
    WidgetsBinding.instance.addObserver(this);
    widget.opening.sessions?.addListener(_sessionChanged);
  }
  void _sessionChanged() {
    if (!widget.opening.sessionMatches) widget.opening.finish();
  }
  @override
  void didPop() => widget.opening.finish();
  @override
  void didPushNext() => widget.opening.hideFeedback();
  @override
  void didPopNext() => widget.opening.restoreFeedback();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.opening.hideFeedback();
    } else {
      widget.opening.restoreFeedback();
    }
  }
  @override
  void dispose() {
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.opening.sessions?.removeListener(_sessionChanged);
    // Navigator teardown need not complete origin.popped. Release callers and
    // the overlay even when the whole origin subtree is disposed.
    widget.opening.finish();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => widget.opening.sessionMatches
      ? Offstage(child: Builder(builder: widget.builder))
      : const SizedBox.shrink();
}
