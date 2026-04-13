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
       super(const DmBadgeState.initial());

  StreamSubscription<int>? _badgeSubscription;
  String? _startedUserId;
  Future<void>? _startInFlight;

  Future<void> ensureStarted() async {
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final startFuture = _ensureStartedInternal();
    _startInFlight = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startInFlight, startFuture)) {
        _startInFlight = null;
      }
    }
  }

  Future<void> _ensureStartedInternal() async {
    final currentUserId = await resolveCurrentUserId(_tokenStore);
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _startedUserId = null;
      emit(state.copyWith(initialized: true));
      return;
    }
    if (_startedUserId == currentUserId && state.initialized) {
      return;
    }
    _startedUserId = currentUserId;
    await _badgeSubscription?.cancel();
    _badgeSubscription = null;

    final token = await readAuthToken(_tokenStore);
    if (token != null) {
      await _realtimeClient.connect(userId: currentUserId, token: token);
    }

    _badgeSubscription = _realtimeClient.badgeStream.listen((count) {
      emit(state.copyWith(unreadCount: count, initialized: true));
    });

    final seed = await _seedUnreadFromConversations(currentUserId);
    emit(state.copyWith(unreadCount: seed, initialized: true));
  }

  Future<int> _seedUnreadFromConversations(String currentUserId) async {
    final result = await _repository.getMyConversations();
    if (!result.isSuccess || result.data == null) {
      return state.unreadCount;
    }
    // Backend listesinde sadece son mesaj okundu bilgisi oldugu icin
    // burada "okunmamis konusma" sayisini seed olarak kullaniyoruz.
    final count = result.data!
        .where(
          (item) =>
              item.lastMessageRead == false &&
              (item.lastMessageSenderId?.trim() ?? '') != currentUserId,
        )
        .length;
    return count;
  }

  @override
  Future<void> close() async {
    await _badgeSubscription?.cancel();
    return super.close();
  }
}
