import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
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

  DmConversationsCubit(
    this._repository,
    this._tokenStore, {
    DmRealtimeClient? realtimeClient,
  }) : _realtimeClient = realtimeClient ?? DmRealtimeClient(),
       super(const DmConversationsState.idle()) {
    _realtimeClient.retain();
    _messageSubscription = _realtimeClient.messageStream.listen(
      _onRealtimeMessage,
    );
  }

  StreamSubscription<DmMessage>? _messageSubscription;
  String? _currentUserId;

  Future<void> load() async {
    emit(state.copyWith(status: DmConversationsStatus.loading, error: null));
    final result = await _repository.getMyConversations();
    if (result.isSuccess) {
      _currentUserId ??= await resolveCurrentUserId(_tokenStore);
      await _ensureRealtimeConnected();
      final sanitized = _sanitizeConversations(result.data ?? const []);
      emit(
        state.copyWith(
          status: DmConversationsStatus.success,
          items: sanitized,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: DmConversationsStatus.failure,
        error: result.error,
      ),
    );
  }

  Future<void> _ensureRealtimeConnected() async {
    final userId = (_currentUserId ?? '').trim();
    if (userId.isEmpty) return;
    final token = await readAuthToken(_tokenStore);
    if (token == null) return;
    await _realtimeClient.connect(userId: userId, token: token);
  }

  void _onRealtimeMessage(DmMessage incoming) {
    final currentUserId = (_currentUserId ?? '').trim();
    if (currentUserId.isEmpty) return;

    final items = [...state.items];
    final index = items.indexWhere(
      (item) => item.conversationId == incoming.conversationId,
    );

    final lastRead = incoming.recipientId == currentUserId
        ? incoming.readAt != null
        : true;

    if (index >= 0) {
      final existing = items[index];
      final updated = DmConversationPreview(
        conversationId: existing.conversationId,
        otherUserId: existing.otherUserId,
        otherUsername: existing.otherUsername,
        otherUserProfilePicture: existing.otherUserProfilePicture,
        lastMessageContent: incoming.content,
        lastMessageType: incoming.messageType,
        lastMessageSenderId: incoming.senderId,
        lastMessageAt: incoming.sentAt,
        lastMessageRead: lastRead,
      );
      items[index] = updated;
      items.sort(_comparePreviewByLastMessage);
      emit(
        state.copyWith(
          status: DmConversationsStatus.success,
          items: items,
          error: null,
        ),
      );
      return;
    }

    // Yeni konusma acildiysa profil bilgilerini backend preview endpointinden al.
    load();
  }

  int _comparePreviewByLastMessage(
    DmConversationPreview a,
    DmConversationPreview b,
  ) {
    final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
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
    await _messageSubscription?.cancel();
    await _realtimeClient.release();
    return super.close();
  }
}
