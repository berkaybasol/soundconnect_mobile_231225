import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import 'entities/dm_conversation_preview.dart';
import 'entities/dm_message.dart';

abstract class DmRepository {
  Future<Result<List<DmConversationPreview>>> getMyConversations();

  Future<Result<Page<DmConversationPreview>>> getMyConversationsPage({
    String? cursor,
    int size = 30,
  });

  Future<Result<DmConversationPreview>> getConversationPreview({
    required String conversationId,
  });

  Future<Result<int>> getUnreadCount();

  Future<Result<String>> getOrCreateConversation({required String otherUserId});

  Future<Result<Page<DmMessage>>> getConversationMessages({
    required String conversationId,
    int page = 0,
    int size = 30,
  });

  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
    String? clientMessageId,
  });

  Future<Result<void>> markMessageAsRead({required String messageId});
}
