import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../notification/domain/entities/app_notification.dart';
import '../../domain/overthinking_repository.dart';
import 'overthinking_incoming_unread_cubit.dart';

/// One application-owned inbox signal shared by every Overthinking entry point.
/// Each authentication session gets an isolated controller; routes never own or
/// close this scope. Their write actions must still check their route session.
class OverthinkingIncomingUnreadScope extends Cubit<bool?>
    with WidgetsBindingObserver {
  OverthinkingIncomingUnreadScope(
    this._repository, {
    AuthSessionManager? sessions,
    Stream<AppNotification>? notifications,
    Stream<void>? reconnections,
    Stream<void>? invalidations,
  }) : _sessions = sessions,
       _notifications = notifications,
       _reconnections = reconnections,
       _invalidations = invalidations,
       super(null) {
    WidgetsBinding.instance.addObserver(this);
    _sessions?.addListener(_sessionChanged);
    _replaceSession();
  }

  final OverthinkingRepository _repository;
  final AuthSessionManager? _sessions;
  final Stream<AppNotification>? _notifications;
  final Stream<void>? _reconnections;
  final Stream<void>? _invalidations;
  AuthSession? _boundSession;
  OverthinkingIncomingUnreadCubit? _current;
  StreamSubscription<bool?>? _subscription;
  Future<void>? _initialRead;
  Future<void>? _refreshInFlight;
  Future<void>? _closing;
  bool _started = false;
  int _generation = 0;

  void _sessionChanged() {
    if (_closing != null ||
        isClosed ||
        identical(_boundSession, _sessions?.session)) {
      return;
    }
    _replaceSession();
  }

  void _replaceSession() {
    final generation = ++_generation;
    final previous = _current;
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    if (previous != null) unawaited(previous.close());
    _boundSession = _sessions?.session;
    _initialRead = null;
    _refreshInFlight = null;
    if (state != null) emit(null);
    final current = OverthinkingIncomingUnreadCubit(
      _repository,
      sessions: _sessions,
      notifications: _notifications,
      reconnections: _reconnections,
      invalidations: _invalidations,
    );
    _current = current;
    _subscription = current.stream.listen((unread) {
      if (_closing == null &&
          !isClosed &&
          generation == _generation &&
          unread == current.state) {
        emit(unread);
      }
    });
    if (_started) unawaited(refresh());
  }

  /// Safe from any number of icon builds: only the first starts a read.
  Future<void> ensureStarted() {
    if (_closing != null || isClosed) return Future<void>.value();
    return _started ? _initialRead ?? Future<void>.value() : refresh();
  }

  Future<void> refresh() {
    if (_closing != null || isClosed) return Future<void>.value();
    _started = true;
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final operation = _current!.refresh();
    _refreshInFlight = operation;
    final read = operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
    _initialRead ??= read;
    return read;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _started) unawaited(refresh());
  }

  Future<void> markSeen() {
    if (_closing != null || isClosed) return Future<void>.value();
    _started = true;
    _refreshInFlight = null;
    final current = _current!;
    final marking = current.markSeen();
    // Cubit's stream is asynchronous; make the shared value available to all
    // entry points in the same call that opens the incoming requests tab.
    emit(current.state);
    return marking;
  }

  @override
  Future<void> close() async {
    final closing = _closing;
    if (closing != null) return closing;
    final completion = Completer<void>();
    _closing = completion.future;
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _sessions?.removeListener(_sessionChanged);
    try {
      await _subscription?.cancel();
      await _current?.close();
    } finally {
      await super.close();
      completion.complete();
    }
  }
}
