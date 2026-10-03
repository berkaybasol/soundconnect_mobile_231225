import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../data/dm_auth_support.dart';
import '../../data/dm_realtime_client.dart';
import '../../domain/dm_repository.dart';
import '../../domain/entities/dm_message.dart';
import 'dm_chat_state.dart';

class DmChatCubit extends Cubit<DmChatState> {
  static const maxMessageLength = 10000;
  final DmRepository _repository;
  final TokenStore _tokenStore;
  final DmRealtimeClient _realtimeClient;
  final void Function(String messageId)? _onReadAcknowledged;
  final AuthSessionManager? _sessions;
  String? _ownerToken;
  String? _ownerId;
  String? _pendingSendContent;
  String? _pendingSendId;

  DmChatCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
    void Function(String messageId)? onReadAcknowledged,
    AuthSessionManager? sessions,
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       _sessions = sessions,
       _onReadAcknowledged = onReadAcknowledged,
       super(const DmChatState.idle()) {
    _realtimeClient.retain();
    _ownerToken = sessions?.session.token;
    _ownerId = sessions?.session.userId;
    sessions?.addListener(_onSessionChanged);
    _realtimeSubscription = _realtimeClient.messageStream.listen(
      _onRealtimeMessage,
    );
  }

  String? _otherUserId;
  String? _currentUserId;
  StreamSubscription<DmMessage>? _realtimeSubscription;
  bool _visible = false;
  Set<String>? _presentedHistory;
  int _generation = 0;
  int _refreshSequence = 0;
  int _messageRevision = 0;
  final Map<String, int> _messageRevisions = {};
  final Set<String> _reading = {};

  bool get _sessionValid =>
      _sessions == null ||
      (_sessions.session.token == _ownerToken &&
          _sessions.session.userId == _ownerId &&
          _sessions.session.isActive &&
          !_sessions.session.requiresListenerProfileChoice);

  void _onSessionChanged() {
    final current = _sessions!.session;
    if (current.token == _ownerToken &&
        current.userId == _ownerId &&
        current.isActive &&
        !current.requiresListenerProfileChoice) {
      return;
    }
    _generation++;
    _visible = false;
    _otherUserId = null;
    _currentUserId = null;
    _pendingSendContent = null;
    _pendingSendId = null;
    _reading.clear();
    _presentedHistory?.clear();
    _messageRevisions.clear();
    if (!isClosed) emit(const DmChatState.idle());
  }

  /// The screen opts in before loading, then authorizes each laid-out history
  /// snapshot. This preserves the loaded-history read policy without allowing
  /// a newly received message to be acknowledged before its frame is presented.
  void requirePresentedHistory() => _presentedHistory ??= <String>{};

  Future<void> acknowledgePresentedHistory(Iterable<String> messageIds) async {
    final presented = _presentedHistory;
    if (presented == null || !_visible || !_sessionValid || isClosed) return;
    var changed = false;
    for (final id in messageIds) {
      if (presented.add(id)) changed = true;
    }
    if (changed) await _markIncomingUnreadAsRead(state.messages);
  }

  /// Only the top conversation route in a resumed app may acknowledge reads.
  void setVisible(bool visible) {
    visible = visible && _sessionValid;
    final becameVisible = !_visible && visible;
    _visible = visible;
    if (!visible) _presentedHistory?.clear();
    if (becameVisible && !isClosed && state.conversationId != null) {
      unawaited(refresh());
    }
  }

  Future<void> openOrCreateConversation({
    required String otherUserId,
    String? currentUserId,
    bool recipientDeleted = false,
  }) async {
    if (isClosed || !_sessionValid) return;
    final generation = ++_generation;
    _pendingSendContent = null;
    _pendingSendId = null;
    _reading.clear();
    _presentedHistory?.clear();
    _messageRevisions.clear();
    _otherUserId = otherUserId;
    final normalizedCurrent = currentUserId?.trim() ?? '';
    _currentUserId = normalizedCurrent.isEmpty ? null : normalizedCurrent;
    emit(
      state.copyWith(
        status: DmChatStatus.loading,
        messages: const [],
        conversationId: null,
        sending: false,
        page: 0,
        hasNext: false,
        error: null,
        recipientDeleted: recipientDeleted,
      ),
    );
    final conversationResult = await _repository.getOrCreateConversation(
      otherUserId: otherUserId,
    );
    if (isClosed || generation != _generation) return;
    if (!conversationResult.isSuccess || conversationResult.data == null) {
      emit(
        state.copyWith(
          status: DmChatStatus.failure,
          error: conversationResult.error,
          recipientDeleted:
              recipientDeleted ||
              _deletedAccount(conversationResult.error?.code),
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
    if (isClosed || !_sessionValid) return;
    final generation = _generation;
    final sequence = ++_refreshSequence;
    final revision = _messageRevision;
    final conversationId = state.conversationId;
    if (conversationId == null || conversationId.trim().isEmpty) {
      return;
    }
    final messagesResult = await _repository.getConversationMessages(
      conversationId: conversationId,
    );
    if (isClosed || generation != _generation || sequence != _refreshSequence) {
      return;
    }
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
    final sorted = _mergeUniqueById([
      ...(page?.items ?? const <DmMessage>[]),
      // WebSocket arrivals, sent messages and successful read ACKs which
      // happened during REST must survive its older page snapshot.
      ...state.messages.where(
        (item) => (_messageRevisions[item.messageId] ?? 0) > revision,
      ),
    ])..sort(_compareMessageTime);
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
    if (isClosed || !_sessionValid) return;
    final generation = _generation;
    final refreshSequence = _refreshSequence;
    final revision = _messageRevision;
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
    if (isClosed ||
        generation != _generation ||
        refreshSequence != _refreshSequence) {
      return;
    }
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
      ...state.messages.where(
        (item) => (_messageRevisions[item.messageId] ?? 0) > revision,
      ),
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
    await _markIncomingUnreadAsRead(messagesResult.data!.items);
  }

  Future<bool> send(String content) async {
    if (isClosed || !_sessionValid || state.sending || state.recipientDeleted) {
      return false;
    }
    final generation = _generation;
    final conversationId = state.conversationId;
    final otherUserId = _otherUserId;
    final trimmed = content.trim();
    if (trimmed.length > maxMessageLength) {
      emit(
        state.copyWith(
          error: const AppError(
            code: 'dm_message_too_long',
            message: 'Mesaj en fazla 10.000 karakter olabilir.',
          ),
        ),
      );
      return false;
    }
    if (conversationId == null ||
        conversationId.trim().isEmpty ||
        otherUserId == null ||
        otherUserId.trim().isEmpty ||
        trimmed.isEmpty) {
      return false;
    }
    if (_pendingSendContent != trimmed) {
      _pendingSendContent = trimmed;
      _pendingSendId = const Uuid().v4();
    }
    emit(state.copyWith(sending: true, error: null));
    final sendResult = await _repository.sendMessage(
      conversationId: conversationId,
      recipientId: otherUserId,
      content: trimmed,
      messageType: 'text',
      clientMessageId: _pendingSendId,
    );
    if (isClosed || generation != _generation) return false;
    if (!sendResult.isSuccess || sendResult.data == null) {
      emit(
        state.copyWith(
          sending: false,
          error: sendResult.error,
          recipientDeleted: _deletedAccount(sendResult.error?.code),
        ),
      );
      return false;
    }
    _currentUserId ??= sendResult.data!.senderId.trim().isEmpty
        ? null
        : sendResult.data!.senderId;
    _pendingSendContent = null;
    _pendingSendId = null;
    _messageRevisions[sendResult.data!.messageId] = ++_messageRevision;
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

  static bool _deletedAccount(String? code) =>
      const {'1008', 'ACCOUNT_DELETED'}.contains(code);

  Future<void> _markIncomingUnreadAsRead(List<DmMessage> messages) async {
    if (!_visible || isClosed) return;
    final generation = _generation;
    final otherUserId = _otherUserId;
    if (otherUserId == null || otherUserId.trim().isEmpty) return;
    for (final message in messages) {
      if (!_visible || isClosed || generation != _generation) return;
      if (message.senderId == otherUserId &&
          (_presentedHistory == null ||
              _presentedHistory!.contains(message.messageId)) &&
          message.readAt == null &&
          _reading.add(message.messageId)) {
        try {
          final result = await _repository.markMessageAsRead(
            messageId: message.messageId,
          );
          if (isClosed || generation != _generation) return;
          if (!result.isSuccess) {
            emit(state.copyWith(error: result.error));
            return;
          }
          _messageRevisions[message.messageId] = ++_messageRevision;
          final updated = state.messages
              .map(
                (item) => item.messageId == message.messageId
                    ? DmMessage(
                        messageId: item.messageId,
                        conversationId: item.conversationId,
                        senderId: item.senderId,
                        recipientId: item.recipientId,
                        content: item.content,
                        messageType: item.messageType,
                        sentAt: item.sentAt,
                        readAt: DateTime.now(),
                        deletedAt: item.deletedAt,
                      )
                    : item,
              )
              .toList();
          emit(state.copyWith(messages: updated, error: null));
          _onReadAcknowledged?.call(message.messageId);
        } finally {
          _reading.remove(message.messageId);
        }
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
    if (isClosed) return;
    final generation = _generation;
    final userId = (_currentUserId ?? '').trim();
    if (userId.isEmpty) {
      final resolved = await resolveCurrentUserId(_tokenStore);
      if (isClosed || generation != _generation) return;
      _currentUserId = resolved;
    }
    final resolvedUserId = (_currentUserId ?? '').trim();
    if (resolvedUserId.isEmpty) return;
    final token = await readAuthToken(_tokenStore);
    if (token == null || isClosed || generation != _generation) return;
    try {
      await _realtimeClient.connect(userId: resolvedUserId, token: token);
    } catch (_) {
      // REST history and read ACK remain usable while realtime reconnects.
    }
  }

  void _onRealtimeMessage(DmMessage incoming) {
    if (incoming.deletedAt != null) return;
    final activeConversationId = state.conversationId?.trim() ?? '';
    if (activeConversationId.isEmpty) return;
    if (incoming.conversationId.trim() != activeConversationId) return;
    _messageRevisions[incoming.messageId] = ++_messageRevision;
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
      final previous = map[item.messageId];
      map[item.messageId] = previous?.readAt != null && item.readAt == null
          ? DmMessage(
              messageId: item.messageId,
              conversationId: item.conversationId,
              senderId: item.senderId,
              recipientId: item.recipientId,
              content: item.content,
              messageType: item.messageType,
              sentAt: item.sentAt,
              readAt: previous!.readAt,
              deletedAt: item.deletedAt,
            )
          : item;
    }
    return map.values.toList();
  }

  @override
  Future<void> close() async {
    _sessions?.removeListener(_onSessionChanged);
    _generation++;
    _visible = false;
    await _realtimeSubscription?.cancel();
    await _realtimeClient.release();
    return super.close();
  }
}
