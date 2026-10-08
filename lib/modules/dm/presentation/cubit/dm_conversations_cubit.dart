import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../data/dm_auth_support.dart';
import '../../data/dm_realtime_client.dart';
import '../../domain/dm_repository.dart';
import '../../domain/entities/dm_conversation_preview.dart';
import '../../domain/entities/dm_message.dart';
import 'dm_conversations_state.dart';

class DmConversationsCubit extends Cubit<DmConversationsState> {
  final DmRepository _repository;
  final TokenStore _tokenStore;
  final DmRealtimeClient _realtimeClient;
  final AuthSessionManager? _sessions;
  String? _ownerToken;
  String? _ownerId;

  DmConversationsCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
    AuthSessionManager? sessions,
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       _sessions = sessions,
       super(const DmConversationsState.idle()) {
    _realtimeClient.retain();
    _ownerToken = sessions?.session.token;
    _ownerId = sessions?.session.userId;
    sessions?.addListener(_onSessionChanged);
    _messageSubscription = _realtimeClient.messageStream.listen(
      _onRealtimeMessage,
    );
    _connectionSubscription = _realtimeClient.connectionStream.listen((
      connected,
    ) {
      if (isClosed || !_sessionValid) return;
      if (!connected) {
        _reconnectPending = _hasLoadedOnce;
      } else if (_reconnectPending) {
        _reconnectPending = false;
        unawaited(load());
      }
    });
  }

  StreamSubscription<DmMessage>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  bool _hasLoadedOnce = false;
  bool _reconnectPending = false;
  String? _currentUserId;
  Future<void>? _loadInFlight;
  bool _reloadRequested = false;
  int _refreshSequence = 0;

  bool get _sessionValid =>
      _sessions == null ||
      (_sessions.session.token == _ownerToken &&
          _sessions.session.userId == _ownerId &&
          _sessions.session.isActive &&
          !_sessions.session.requiresListenerProfileChoice);

  void _onSessionChanged() {
    if (_sessionValid || isClosed) return;
    _reloadRequested = false;
    _refreshSequence++;
    _currentUserId = null;
    _reconnectPending = false;
    emit(const DmConversationsState.idle());
  }

  Future<void> load() {
    if (isClosed || !_sessionValid) return Future.value();
    _reloadRequested = true;
    _refreshSequence++;
    final existing = _loadInFlight;
    if (existing != null) return existing;
    final operation = _loadPending();
    _loadInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_loadInFlight, operation)) _loadInFlight = null;
      if (_reloadRequested && !isClosed) unawaited(load());
    });
  }

  Future<void> _loadPending() async {
    while (_reloadRequested && !isClosed && _sessionValid) {
      _reloadRequested = false;
      await _loadOnce();
    }
  }

  Future<void> _loadOnce() async {
    final sequence = _refreshSequence;
    emit(
      state.copyWith(
        status: DmConversationsStatus.loading,
        loadingMore: false,
        error: null,
        loadMoreError: null,
      ),
    );
    final result = await _repository.getMyConversationsPage();
    if (isClosed || !_sessionValid || sequence != _refreshSequence) return;
    if (result.isSuccess) {
      _currentUserId = await resolveCurrentUserId(_tokenStore);
      if (isClosed || !_sessionValid || sequence != _refreshSequence) return;
      try {
        await _ensureRealtimeConnected();
      } catch (_) {
        // Conversation history remains usable when realtime is unavailable.
      }
      if (isClosed || !_sessionValid || sequence != _refreshSequence) return;
      final sanitized = _sanitizeConversations(result.data?.items ?? const []);
      emit(
        state.copyWith(
          status: DmConversationsStatus.success,
          items: sanitized,
          hasNext: result.data?.hasNext ?? false,
          nextCursor: result.data?.nextCursor,
          error: null,
        ),
      );
      _hasLoadedOnce = true;
      return;
    }
    emit(
      state.copyWith(
        status: DmConversationsStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<void> loadMore() async {
    if (isClosed ||
        !_sessionValid ||
        state.loadingMore ||
        state.status == DmConversationsStatus.loading ||
        !state.hasNext) {
      return;
    }
    final cursor = state.nextCursor;
    if (cursor == null) return;
    final sequence = _refreshSequence;
    emit(state.copyWith(loadingMore: true, loadMoreError: null));
    final result = await _repository.getMyConversationsPage(cursor: cursor);
    if (isClosed || !_sessionValid || sequence != _refreshSequence) return;
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(loadingMore: false, loadMoreError: result.error));
      return;
    }
    final merged = <String, DmConversationPreview>{
      for (final item in [...state.items, ...result.data!.items])
        item.conversationId: item,
    };
    emit(
      state.copyWith(
        items: _sanitizeConversations(merged.values.toList()),
        hasNext: result.data!.hasNext,
        nextCursor: result.data!.nextCursor,
        loadingMore: false,
        loadMoreError: null,
      ),
    );
  }

  Future<void> _ensureRealtimeConnected() async {
    final userId = (_currentUserId ?? '').trim();
    if (userId.isEmpty) return;
    final token = await readAuthToken(_tokenStore);
    if (token == null || isClosed || !_sessionValid) return;
    await _realtimeClient.connect(userId: userId, token: token);
  }

  void _onRealtimeMessage(DmMessage incoming) {
    if (isClosed || !_sessionValid) return;
    final currentUserId = (_currentUserId ?? '').trim();
    if (currentUserId.isEmpty) return;
    if (incoming.senderId != currentUserId &&
        incoming.recipientId != currentUserId) {
      return;
    }
    // Visibility and deletion may have changed since the last projection.
    // Never attach new message content to a stale real listener identity.
    unawaited(load());
  }

  int _comparePreviewByLastMessage(
    DmConversationPreview a,
    DmConversationPreview b,
  ) {
    final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final time = bTime.compareTo(aTime);
    return time != 0 ? time : b.conversationId.compareTo(a.conversationId);
  }

  List<DmConversationPreview> _sanitizeConversations(
    List<DmConversationPreview> items,
  ) {
    final filtered = items.where((item) {
      if (item.conversationId.trim().isEmpty) return false;
      if (item.otherUserId.trim().isEmpty) return false;
      final hasMessageText = (item.lastMessageContent ?? '').trim().isNotEmpty;
      final hasMessageTime = item.lastMessageAt != null;
      final hasMessageType = (item.lastMessageType ?? '').trim().isNotEmpty;
      final hasMessageSender = (item.lastMessageSenderId ?? '')
          .trim()
          .isNotEmpty;
      return hasMessageText ||
          hasMessageTime ||
          hasMessageType ||
          hasMessageSender;
    }).toList();
    filtered.sort(_comparePreviewByLastMessage);
    return filtered;
  }

  @override
  Future<void> close() async {
    _sessions?.removeListener(_onSessionChanged);
    await _messageSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _realtimeClient.release();
    return super.close();
  }
}
