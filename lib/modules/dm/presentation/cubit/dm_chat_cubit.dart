import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../data/dm_auth_support.dart';
import '../../data/dm_realtime_client.dart';
import '../../domain/dm_repository.dart';
import '../../domain/entities/dm_message.dart';
import 'dm_chat_state.dart';

class DmChatCubit extends Cubit<DmChatState> {
  final DmRepository _repository;
  final TokenStore _tokenStore;
  final DmRealtimeClient _realtimeClient;

  DmChatCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       super(const DmChatState.idle()) {
    _realtimeClient.retain();
    _realtimeSubscription = _realtimeClient.messageStream.listen(
      _onRealtimeMessage,
    );
  }

  String? _otherUserId;
  String? _currentUserId;
  StreamSubscription<DmMessage>? _realtimeSubscription;

  Future<void> openOrCreateConversation({
    required String otherUserId,
    String? currentUserId,
  }) async {
    _otherUserId = otherUserId;
    final normalizedCurrent = currentUserId?.trim() ?? '';
    if (normalizedCurrent.isNotEmpty) {
      _currentUserId = normalizedCurrent;
    }
    emit(
      state.copyWith(
        status: DmChatStatus.loading,
        messages: const [],
        page: 0,
        hasNext: false,
        error: null,
      ),
    );
    final conversationResult = await _repository.getOrCreateConversation(
      otherUserId: otherUserId,
    );
    if (!conversationResult.isSuccess || conversationResult.data == null) {
      emit(
        state.copyWith(
          status: DmChatStatus.failure,
          error: conversationResult.error,
        ),
      );
      return;
    }
    final conversationId = conversationResult.data!;
    emit(state.copyWith(conversationId: conversationId));
    await refresh();
    await _ensureRealtimeConnected();
  }

  Future<void> refresh() async {
    final conversationId = state.conversationId;
    if (conversationId == null || conversationId.trim().isEmpty) {
      return;
    }
    final messagesResult = await _repository.getConversationMessages(
      conversationId: conversationId,
    );
    if (!messagesResult.isSuccess) {
      emit(
        state.copyWith(
          status: DmChatStatus.failure,
          error: messagesResult.error,
        ),
      );
      return;
    }
    final page = messagesResult.data;
    final sorted = [...(page?.items ?? const <DmMessage>[])]
      ..sort(_compareMessageTime);
    _tryResolveCurrentUserId(sorted);
    emit(
      state.copyWith(
        status: DmChatStatus.success,
        messages: sorted,
        page: 0,
        hasNext: page?.hasNext ?? false,
        error: null,
      ),
    );
    await _markIncomingUnreadAsRead(sorted);
    await _ensureRealtimeConnected();
  }

  Future<void> loadMore() async {
    final conversationId = state.conversationId;
    if (conversationId == null ||
        conversationId.trim().isEmpty ||
        !state.hasNext ||
        state.status == DmChatStatus.loadingMore) {
      return;
    }

    final nextPage = state.page + 1;
    emit(state.copyWith(status: DmChatStatus.loadingMore, error: null));
    final messagesResult = await _repository.getConversationMessages(
      conversationId: conversationId,
      page: nextPage,
    );
    if (!messagesResult.isSuccess || messagesResult.data == null) {
      emit(
        state.copyWith(
          status: DmChatStatus.success,
          error: messagesResult.error,
        ),
      );
      return;
    }

    final merged = _mergeUniqueById([
      ...state.messages,
      ...messagesResult.data!.items,
    ])..sort(_compareMessageTime);
    _tryResolveCurrentUserId(merged);
    emit(
      state.copyWith(
        status: DmChatStatus.success,
        messages: merged,
        page: nextPage,
        hasNext: messagesResult.data!.hasNext,
        error: null,
      ),
    );
  }

  Future<bool> send(String content) async {
    if (state.sending) return false;
    final conversationId = state.conversationId;
    final otherUserId = _otherUserId;
    final trimmed = content.trim();
    if (conversationId == null ||
        conversationId.trim().isEmpty ||
        otherUserId == null ||
        otherUserId.trim().isEmpty ||
        trimmed.isEmpty) {
      return false;
    }
    emit(state.copyWith(sending: true, error: null));
    final sendResult = await _repository.sendMessage(
      conversationId: conversationId,
      recipientId: otherUserId,
      content: trimmed,
      messageType: 'text',
    );
    if (!sendResult.isSuccess || sendResult.data == null) {
      emit(state.copyWith(sending: false, error: sendResult.error));
      return false;
    }
    _currentUserId ??= sendResult.data!.senderId.trim().isEmpty
        ? null
        : sendResult.data!.senderId;
    final next = _mergeUniqueById([...state.messages, sendResult.data!])
      ..sort(_compareMessageTime);
    emit(
      state.copyWith(
        status: DmChatStatus.success,
        sending: false,
        messages: next,
        hasNext: state.hasNext,
        error: null,
      ),
    );
    await _ensureRealtimeConnected();
    return true;
  }

  int _compareMessageTime(DmMessage a, DmMessage b) {
    final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return aTime.compareTo(bTime);
  }

  Future<void> _markIncomingUnreadAsRead(List<DmMessage> messages) async {
    final otherUserId = _otherUserId;
    if (otherUserId == null || otherUserId.trim().isEmpty) return;
    for (final message in messages) {
      if (message.senderId == otherUserId && message.readAt == null) {
        await _repository.markMessageAsRead(messageId: message.messageId);
      }
    }
  }

  void _tryResolveCurrentUserId(List<DmMessage> messages) {
    if (_currentUserId != null && _currentUserId!.trim().isNotEmpty) return;
    final otherUserId = _otherUserId;
    if (otherUserId == null || otherUserId.trim().isEmpty) return;
    for (final item in messages) {
      if (item.senderId == otherUserId && item.recipientId != otherUserId) {
        _currentUserId = item.recipientId;
        return;
      }
      if (item.recipientId == otherUserId && item.senderId != otherUserId) {
        _currentUserId = item.senderId;
        return;
      }
    }
  }

  Future<void> _ensureRealtimeConnected() async {
    final userId = (_currentUserId ?? '').trim();
    if (userId.isEmpty) {
      _currentUserId = await resolveCurrentUserId(_tokenStore);
    }
    final resolvedUserId = (_currentUserId ?? '').trim();
    if (resolvedUserId.isEmpty) return;
    final token = await readAuthToken(_tokenStore);
    if (token == null) return;
    await _realtimeClient.connect(userId: resolvedUserId, token: token);
  }

  void _onRealtimeMessage(DmMessage incoming) {
    if (incoming.deletedAt != null) return;
    final activeConversationId = state.conversationId?.trim() ?? '';
    if (activeConversationId.isEmpty) return;
    if (incoming.conversationId.trim() != activeConversationId) return;
    final next = _mergeUniqueById([...state.messages, incoming])
      ..sort(_compareMessageTime);
    emit(
      state.copyWith(status: DmChatStatus.success, messages: next, error: null),
    );
    _markIncomingUnreadAsRead([incoming]);
  }

  List<DmMessage> _mergeUniqueById(List<DmMessage> values) {
    final map = <String, DmMessage>{};
    for (final item in values) {
      map[item.messageId] = item;
    }
    return map.values.toList();
  }

  @override
  Future<void> close() async {
    await _realtimeSubscription?.cancel();
    await _realtimeClient.release();
    return super.close();
  }
}
