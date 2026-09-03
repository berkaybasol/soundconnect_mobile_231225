import '../../../profile/domain/entities/listener_visibility_mode.dart';

class DmConversationPreview {
  final String conversationId;
  final String otherUserId;
  final String otherUsername;
  final String? otherUserProfilePicture;
  final String? lastMessageContent;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final bool? lastMessageRead;
  final ListenerVisibilityMode otherUserVisibilityMode;

  const DmConversationPreview({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherUserProfilePicture,
    required this.lastMessageContent,
    required this.lastMessageType,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.lastMessageRead,
    this.otherUserVisibilityMode = ListenerVisibilityMode.standard,
  });

  bool get isOtherUserGhost => otherUserVisibilityMode.isGhost;
}
