import 'dm_timestamp.dart';
import '../../domain/entities/dm_message.dart';

class DmMessageModel extends DmMessage {
  const DmMessageModel({
    required super.messageId,
    required super.conversationId,
    required super.senderId,
    required super.recipientId,
    required super.content,
    required super.messageType,
    required super.sentAt,
    required super.readAt,
    required super.deletedAt,
  });

  factory DmMessageModel.fromJson(Map<String, dynamic> json) {
    return DmMessageModel(
      messageId: json['messageId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      recipientId: json['recipientId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      sentAt: parseDmTimestamp(json['sentAt']),
      readAt: parseDmTimestamp(json['readAt']),
      deletedAt: parseDmTimestamp(json['deletedAt']),
    );
  }
}
