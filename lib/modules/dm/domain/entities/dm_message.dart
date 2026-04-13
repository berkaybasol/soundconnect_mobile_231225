class DmMessage {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String content;
  final String messageType;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime? deletedAt;

  const DmMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.messageType,
    required this.sentAt,
    required this.readAt,
    required this.deletedAt,
  });
}
