import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../data/dm_auth_support.dart';
import '../../data/dm_realtime_client.dart';
import '../../domain/dm_repository.dart';
import 'dm_badge_state.dart';

class DmBadgeCubit extends Cubit<DmBadgeState> {
  final DmRepository _repository;
  final TokenStore _tokenStore;
  final DmRealtimeClient _realtimeClient;
  final AuthSessionManager? _sessions;
  String? _sessionToken;
  String? _sessionUserId;
  bool _sessionEligible = false;

  DmBadgeCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
    AuthSessionManager? sessions,
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       _sessions = sessions,
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

  Future<void> _seedUnreadCount(int generation) async {
    final sequence = ++_seedSequence;
    final revisionBeforeRequest = _badgeRevision;
    final result = await _repository.getUnreadCount();
    if (!_isCurrent(generation) || sequence != _seedSequence) return;

    // A realtime update that arrives while REST is in flight is newer and
    // must not be overwritten by the seed response.
    if (_badgeRevision != revisionBeforeRequest) return;

    final count = result.isSuccess && result.data != null
        ? result.data!.clamp(0, 999999)
        : state.unreadCount;
    emit(state.copyWith(unreadCount: count, initialized: true));
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
