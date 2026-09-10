import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../notification/domain/entities/app_notification.dart';
import '../../domain/entities/overthinking_incoming_unread_status.dart';
import '../../domain/overthinking_repository.dart';
import '../../domain/overthinking_session.dart';

/// New incoming requests since the inbox was last opened, independent of
/// whether their reveal decisions are still pending. Null means unknown.
class OverthinkingIncomingUnreadCubit extends Cubit<bool?> {
  OverthinkingIncomingUnreadCubit(
    this._repository, {
    AuthSessionManager? sessions,
    Stream<AppNotification>? notifications,
    Stream<void>? reconnections,
    Stream<void>? invalidations,
  }) : _session = OverthinkingSession(sessions),
       _recipientId = sessions?.session.userId,
       super(null) {
    _session.addListener(_sessionChanged);
    _notifications = notifications?.listen(_notificationReceived);
    _reconnections = reconnections?.listen((_) => unawaited(refresh()));
    _invalidations = invalidations?.listen((_) => unawaited(refresh()));
  }

  final OverthinkingRepository _repository;
  final OverthinkingSession _session;
  final String? _recipientId;
  StreamSubscription<AppNotification>? _notifications;
  StreamSubscription<void>? _reconnections;
  StreamSubscription<void>? _invalidations;
  OverthinkingIncomingUnreadStatus? _snapshot;
  Future<void>? _readInFlight;
  Future<void>? _seenInFlight;
  Future<void>? _closing;
  bool _refreshQueued = false;
  bool _refreshAfterSeen = false;
  bool _seenQueued = false;
  int _readGeneration = 0;
  int _seenGeneration = 0;
  int _notificationGeneration = 0;

  bool get _active => _closing == null && !isClosed && _session.canWrite;

  void _sessionChanged() {
    ++_readGeneration;
    ++_seenGeneration;
    _refreshQueued = _refreshAfterSeen = _seenQueued = false;
    _snapshot = null;
    if (_closing == null && !isClosed) emit(null);
  }

  void _notificationReceived(AppNotification notification) {
    if (!_active ||
        notification.type != 'OVERTHINKING_REVEAL_REQUEST_RECEIVED' ||
        (_recipientId != null && notification.recipientId != _recipientId)) {
      return;
    }
    ++_notificationGeneration;
    // Delivery can lag behind inbox acknowledgement or replay after reconnect.
    // Only the server's unread status can distinguish a new request from that.
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (!_active) return Future<void>.value();
    final seen = _seenInFlight;
    if (seen != null) {
      _refreshAfterSeen = true;
      return seen;
    }
    ++_readGeneration;
    final reading = _readInFlight;
    if (reading != null) {
      _refreshQueued = true;
      return reading;
    }
    final operation = _refreshLoop();
    _readInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_readInFlight, operation)) _readInFlight = null;
    });
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshQueued = false;
      final generation = _readGeneration;
      try {
        final result = await _repository.getIncomingUnreadStatus();
        if (_active &&
            generation == _readGeneration &&
            _seenInFlight == null &&
            result.isSuccess &&
            result.data != null) {
          _snapshot = result.data;
          emit(_snapshot!.hasUnread);
        }
      } catch (_) {
        // Keep known unread state on a transient error; never invent a read.
      }
    } while (_active && _refreshQueued && _seenInFlight == null);
  }

  /// Call when the incoming tab is entered. The dot closes immediately, and
  /// the server acknowledges only the snapshot observed for this opening.
  Future<void> markSeen() {
    if (!_active) return Future<void>.value();
    ++_readGeneration;
    ++_seenGeneration;
    emit(false);
    final seeing = _seenInFlight;
    if (seeing != null) {
      _seenQueued = true;
      return seeing;
    }
    final operation = _markSeenLoop();
    _seenInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_seenInFlight, operation)) _seenInFlight = null;
      if (_active && _refreshAfterSeen) {
        _refreshAfterSeen = false;
        unawaited(refresh());
      }
    });
  }

  Future<void> _markSeenLoop() async {
    do {
      _seenQueued = false;
      final generation = _seenGeneration;
      final notifications = _notificationGeneration;
      final previous = _snapshot;
      try {
        final status = await _repository.getIncomingUnreadStatus();
        if (!_active) return;
        if (generation != _seenGeneration) continue;
        if (!status.isSuccess || status.data == null) {
          emit(previous?.hasUnread);
          return;
        }
        final fresh = status.data!;
        _snapshot = fresh;
        final notificationArrived = notifications != _notificationGeneration;
        // A concurrent frame may represent a newer request. Preserve the
        // opening watermark while deriving the dot solely from server data;
        // the frame itself may also be a replay of an already-seen request.
        if (notificationArrived && previous == null) {
          emit(fresh.hasUnread);
          return;
        }
        final result = await _repository.markIncomingRequestsSeen(
          revision: notificationArrived ? previous!.revision : fresh.revision,
        );
        if (!_active) return;
        if (result.isSuccess && result.data != null) _snapshot = result.data;
        if (generation != _seenGeneration) continue;
        emit(_snapshot?.hasUnread);
        if (!result.isSuccess) _refreshAfterSeen = true;
      } catch (_) {
        if (_active && generation == _seenGeneration) {
          emit(_snapshot?.hasUnread);
          _refreshAfterSeen = true;
        }
      }
    } while (_active && _seenQueued);
  }

  @override
  Future<void> close() async {
    final closing = _closing;
    if (closing != null) return closing;
    final completion = Completer<void>();
    _closing = completion.future;
    ++_readGeneration;
    ++_seenGeneration;
    _refreshQueued = _refreshAfterSeen = _seenQueued = false;
    _session
      ..removeListener(_sessionChanged)
      ..dispose();
    try {
      await _notifications?.cancel();
      await _reconnections?.cancel();
      await _invalidations?.cancel();
    } finally {
      await super.close();
      completion.complete();
    }
  }
}
