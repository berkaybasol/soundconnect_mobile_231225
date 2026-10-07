import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../data/dm_auth_support.dart';
import '../../data/dm_realtime_client.dart';
import '../../domain/dm_repository.dart';
import 'dm_badge_state.dart';

class DmBadgeCubit extends Cubit<DmBadgeState> {
  final DmRepository _repository;
  final TokenStore _tokenStore;
  final DmRealtimeClient _realtimeClient;
  final AuthSessionManager? _sessions;
  final Duration _countReconciliationTimeout;
  String? _sessionToken;
  String? _sessionUserId;
  bool _sessionEligible = false;

  DmBadgeCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
    AuthSessionManager? sessions,
    Duration countReconciliationTimeout = const Duration(seconds: 15),
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       _sessions = sessions,
       _countReconciliationTimeout = countReconciliationTimeout,
       super(const DmBadgeState.initial()) {
    _realtimeClient.retain();
    _sessionToken = sessions?.session.token;
    _sessionUserId = sessions?.session.userId;
    _sessionEligible = _eligible;
    sessions?.addListener(_onSessionChanged);
  }

  StreamSubscription<int>? _badgeSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Future<void>? _resumeInFlight;
  String? _startedUserId;
  Future<void>? _startInFlight;
  int _lifecycleGeneration = 0;
  int _badgeRevision = 0;
  int _seedSequence = 0;
  int _readRevision = 0;
  bool _readReconciliationNeeded = false;
  bool _verifyBadgeAfterRead = false;
  Timer? _badgeReconciliationTimer;
  Future<void>? _countInFlight;
  Completer<void>? _countCancellation;
  bool _realtimeReady = false;
  Future<void>? _stopInFlight;
  bool _closing = false;

  bool get _eligible =>
      !_closing &&
      (_sessions == null ||
          (_sessions.session.isAuthenticated &&
              _sessions.session.isActive &&
              !_sessions.session.requiresListenerProfileChoice));

  void _onSessionChanged() {
    final current = _sessions!.session;
    if (_sessionToken == current.token &&
        _sessionUserId == current.userId &&
        _sessionEligible == _eligible) {
      return;
    }
    _sessionToken = current.token;
    _sessionUserId = current.userId;
    _sessionEligible = _eligible;
    unawaited(
      stop().then((_) async {
        if (!isClosed &&
            _eligible &&
            _sessions.session.token == current.token &&
            _sessions.session.userId == current.userId) {
          await ensureStarted();
        }
      }),
    );
  }

  Future<void> ensureStarted() async {
    final stopping = _stopInFlight;
    if (stopping != null) await stopping;
    if (isClosed || !_eligible) return;
    final requestGeneration = _lifecycleGeneration;
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      if (!_isCurrent(requestGeneration)) {
        return;
      }
    }
    if (!_isCurrent(requestGeneration)) return;
    final startFuture = _ensureStartedInternal(requestGeneration);
    _startInFlight = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startInFlight, startFuture)) {
        _startInFlight = null;
      }
    }
  }

  Future<void> _ensureStartedInternal(int generation) async {
    final currentUserId = await resolveCurrentUserId(_tokenStore);
    if (!_isCurrent(generation)) return;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _startedUserId = null;
      emit(state.copyWith(initialized: true));
      return;
    }
    if (_startedUserId == currentUserId && state.initialized) {
      if (!_realtimeReady || !_realtimeClient.isConnected) {
        await _connectRealtime(currentUserId, generation);
        await _seedUnreadCount(generation);
      } else if (_readReconciliationNeeded) {
        await _seedUnreadCount(generation);
      }
      return;
    }
    _startedUserId = currentUserId;
    _realtimeReady = false;
    await _badgeSubscription?.cancel();
    await _connectionSubscription?.cancel();
    if (!_isCurrent(generation)) return;
    _connectionSubscription = _realtimeClient.connectionStream.listen((
      connected,
    ) {
      if (!_isCurrent(generation)) return;
      final recovered = connected && !_realtimeReady && state.initialized;
      _realtimeReady = connected;
      if (recovered) unawaited(_seedUnreadCount(generation));
    });
    _badgeSubscription = _realtimeClient.badgeStream.listen((count) {
      if (_isCurrent(generation)) {
        _badgeRevision += 1;
        if (_verifyBadgeAfterRead) {
          // An unversioned count may have been published before our ACK, even
          // after its post-read HTTP snapshot was already accepted. Keep the
          // last verified value and coalesce a fresh count for this session.
          _readReconciliationNeeded = true;
          // One fixed window: sustained traffic cannot postpone it forever.
          // An active flight already observes this revision and owns its retry.
          if (_countInFlight != null || _badgeReconciliationTimer != null) {
            return;
          }
          _badgeReconciliationTimer = Timer(
            const Duration(milliseconds: 250),
            () {
              _badgeReconciliationTimer = null;
              if (_isCurrent(generation) && _readReconciliationNeeded) {
                unawaited(_seedUnreadCount(generation));
              }
            },
          );
          return;
        }
        emit(
          state.copyWith(
            unreadCount: count.clamp(0, 999999),
            initialized: true,
          ),
        );
      }
    });

    await _connectRealtime(currentUserId, generation);
    if (!_isCurrent(generation)) {
      await _realtimeClient.disconnect();
      return;
    }

    await _seedUnreadCount(generation);
  }

  Future<void> _connectRealtime(String userId, int generation) async {
    final token = await readAuthToken(_tokenStore);
    if (!_isCurrent(generation)) return;
    if (token == null) {
      _realtimeReady = false;
      return;
    }

    try {
      await _realtimeClient.connect(userId: userId, token: token);
    } catch (_) {
      if (_isCurrent(generation)) _realtimeReady = false;
      return;
    }

    if (!_isCurrent(generation)) {
      await _realtimeClient.disconnect();
      return;
    }
    _realtimeReady = true;
  }

  /// A successful current-session read is independent of best-effort WS badge
  /// delivery. Reuse the same count flight as startup/reconnect/resume; no
  /// optimistic subtraction, because the current badge may already include it.
  Future<void> reconcileAfterRead() {
    final generation = _lifecycleGeneration;
    if (!_isCurrent(generation)) return Future<void>.value();
    _readRevision++;
    _readReconciliationNeeded = true;
    _verifyBadgeAfterRead = true;
    return _reconcileAfterRead(generation);
  }

  Future<void> _reconcileAfterRead(int generation) async {
    if (_startedUserId == null) await ensureStarted();
    if (_isCurrent(generation) &&
        _startedUserId != null &&
        _readReconciliationNeeded) {
      await _seedUnreadCount(generation);
    }
  }

  Future<void> _seedUnreadCount(int generation) {
    if (!_isCurrent(generation)) return Future<void>.value();
    final existing = _countInFlight;
    if (existing != null) return existing;
    _badgeReconciliationTimer?.cancel();
    _badgeReconciliationTimer = null;
    final cancellation = Completer<void>();
    _countCancellation = cancellation;
    // Install the identity before invoking repository code, including a
    // synchronous exception or cancellation. Its finally can then retire it.
    final completion = Completer<void>();
    _countInFlight = completion.future;
    unawaited(
      _runCountReconciliation(generation, cancellation).then<void>(
        (_) => completion.complete(),
        onError: (Object error, StackTrace stack) =>
            completion.completeError(error, stack),
      ),
    );
    return completion.future;
  }

  Future<void> _runCountReconciliation(
    int generation,
    Completer<void> cancellation,
  ) async {
    // Each additional confirmed read can require one later snapshot. N such
    // revisions therefore cost at most N+2 requests; WS contention alone gets
    // one follow-up. No repeat ACK, timer polling, or retry loop on failures.
    var contentionRetryAvailable = true;
    try {
      while (_isCurrent(generation)) {
        _seedSequence++;
        final readRevision = _readRevision;
        final badgeRevision = _badgeRevision;
        final timeout = Completer<Result<int>?>();
        final timer = Timer(
          _countReconciliationTimeout,
          () => timeout.complete(null),
        );
        Result<int>? result;
        try {
          result = await Future.any<Result<int>?>([
            _repository.getUnreadCount(),
            timeout.future,
            cancellation.future.then((_) => null),
          ]);
        } catch (_) {
          // Projection failures never repeat an ACK or escape an unawaited
          // reconnect callback. Keep any read debt for an existing retry path.
        } finally {
          timer.cancel();
        }
        if (!_isCurrent(generation)) return;
        if (result == null || !result.isSuccess || result.data == null) {
          emit(state.copyWith(initialized: true));
          return;
        }
        // Several completed reads during one HTTP request coalesce into one
        // later snapshot. The chat continues its next ACK while this waits.
        if (_readRevision != readRevision) continue;
        if (_badgeRevision != badgeRevision) {
          // Preserve ordinary WS-over-seed behavior. With local read debt an
          // unversioned frame is not proof of the post-ACK total: retry once.
          if (_readReconciliationNeeded && contentionRetryAvailable) {
            contentionRetryAvailable = false;
            continue;
          }
          return;
        }
        _readReconciliationNeeded = false;
        _badgeReconciliationTimer?.cancel();
        _badgeReconciliationTimer = null;
        emit(
          state.copyWith(
            unreadCount: result.data!.clamp(0, 999999),
            initialized: true,
          ),
        );
        return;
      }
    } finally {
      // Retire synchronously with the loop, so a new ACK cannot join a finished
      // flight before a later completion callback clears its identity.
      if (identical(_countCancellation, cancellation)) {
        _countInFlight = null;
        _countCancellation = null;
      }
    }
  }

  Future<void> stop() {
    final existing = _stopInFlight;
    if (existing != null) return existing;
    final operation = _stop();
    _stopInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_stopInFlight, operation)) _stopInFlight = null;
    });
  }

  Future<void> _stop() async {
    _lifecycleGeneration += 1;
    final cancellation = _countCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    _countInFlight = null;
    _countCancellation = null;
    _readReconciliationNeeded = false;
    _verifyBadgeAfterRead = false;
    _badgeReconciliationTimer?.cancel();
    _badgeReconciliationTimer = null;
    _readRevision = 0;
    _resumeInFlight = null;
    _badgeRevision = 0;
    _realtimeReady = false;
    _startedUserId = null;
    await _badgeSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _badgeSubscription = null;
    await _realtimeClient.disconnect();
    if (!isClosed) emit(const DmBadgeState.initial());
  }

  bool _isCurrent(int generation) {
    return !isClosed && _eligible && generation == _lifecycleGeneration;
  }

  Future<void> reconcileAfterResume() {
    final existing = _resumeInFlight;
    if (existing != null) return existing;
    final operation = _reconcileAfterResume();
    _resumeInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_resumeInFlight, operation)) _resumeInFlight = null;
    });
  }

  Future<void> _reconcileAfterResume() async {
    final generation = _lifecycleGeneration;
    final seedBefore = _seedSequence;
    await ensureStarted();
    if (_isCurrent(generation) &&
        _startedUserId != null &&
        seedBefore == _seedSequence) {
      await _seedUnreadCount(generation);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    _sessions?.removeListener(_onSessionChanged);
    await stop();
    await _realtimeClient.release();
    return super.close();
  }
}
