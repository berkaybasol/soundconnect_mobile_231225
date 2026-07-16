import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../data/dm_auth_support.dart';
import '../../data/dm_realtime_client.dart';
import '../../domain/dm_repository.dart';
import 'dm_badge_state.dart';

class DmBadgeCubit extends Cubit<DmBadgeState> {
  final DmRepository _repository;
  final TokenStore _tokenStore;
  final DmRealtimeClient _realtimeClient;

  DmBadgeCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       super(const DmBadgeState.initial()) {
    _realtimeClient.retain();
  }

  StreamSubscription<int>? _badgeSubscription;
  String? _startedUserId;
  Future<void>? _startInFlight;
  int _lifecycleGeneration = 0;
  int _badgeRevision = 0;
  bool _realtimeReady = false;

  Future<void> ensureStarted() async {
    final requestGeneration = _lifecycleGeneration;
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      if (!_isCurrent(requestGeneration) ||
          _startedUserId != null ||
          state.initialized) {
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
      if (!_realtimeReady) {
        await _connectRealtime(currentUserId, generation);
      }
      return;
    }
    _startedUserId = currentUserId;
    _realtimeReady = false;
    await _badgeSubscription?.cancel();
    if (!_isCurrent(generation)) return;
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
    final revisionBeforeRequest = _badgeRevision;
    final result = await _repository.getUnreadCount();
    if (!_isCurrent(generation)) return;

    // A realtime update that arrives while REST is in flight is newer and
    // must not be overwritten by the seed response.
    if (_badgeRevision != revisionBeforeRequest) return;

    final count = result.isSuccess && result.data != null
        ? result.data!.clamp(0, 999999)
        : state.unreadCount;
    emit(state.copyWith(unreadCount: count, initialized: true));
  }

  Future<void> stop() async {
    _lifecycleGeneration += 1;
    _badgeRevision = 0;
    _realtimeReady = false;
    _startedUserId = null;
    await _badgeSubscription?.cancel();
    _badgeSubscription = null;
    await _realtimeClient.disconnect();
    if (!isClosed) emit(const DmBadgeState.initial());
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _lifecycleGeneration;
  }

  @override
  Future<void> close() async {
    await stop();
    await _realtimeClient.release();
    return super.close();
  }
}
