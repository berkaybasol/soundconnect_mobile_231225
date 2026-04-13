import '../../../core/error/result.dart';
import 'entities/dm_conversation_preview.dart';
import 'entities/dm_message.dart';

abstract class DmRepository {
  Future<Result<List<DmConversationPreview>>> getMyConversations();

  Future<Result<String>> getOrCreateConversation({required String otherUserId});

  Future<Result<List<DmMessage>>> getConversationMessages({
    required String conversationId,
  });

  Future<Result<DmMessage>> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String messageType = 'text',
  });

  Future<Result<void>> markMessageAsRead({required String messageId});
}
