import '../../domain/entities/dm_conversation_preview.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';

class DmConversationPreviewModel extends DmConversationPreview {
  const DmConversationPreviewModel({
    required super.conversationId,
    required super.otherUserId,
    required super.otherUsername,
    required super.otherUserProfilePicture,
    required super.lastMessageContent,
    required super.lastMessageType,
    required super.lastMessageSenderId,
    required super.lastMessageAt,
    required super.lastMessageRead,
    super.otherUserVisibilityMode,
  });

  factory DmConversationPreviewModel.fromJson(Map<String, dynamic> json) {
    return DmConversationPreviewModel(
      conversationId: json['conversationId']?.toString() ?? '',
      otherUserId: json['otherUserId']?.toString() ?? '',
      otherUsername: _resolveUsername(json),
      otherUserProfilePicture: json['otherUserProfilePicture']?.toString(),
      lastMessageContent: json['lastMessageContent']?.toString(),
      lastMessageType: json['lastMessageType']?.toString(),
      lastMessageSenderId: json['lastMessageSenderId']?.toString(),
      lastMessageAt: _toDate(json['lastMessageAt']),
      lastMessageRead: _toBool(json['lastMessageRead']),
      otherUserVisibilityMode: parseContextualListenerVisibilityMode(
        json['otherUserVisibilityMode'],
      ),
    );
  }

  static DateTime? _toDate(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _resolveUsername(Map<String, dynamic> json) {
    final candidates = <Object?>[
      json['otherUsername'],
      json['otherUserUsername'],
      json['username'],
      json['otherUserName'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Kullanici';
  }

  static bool? _toBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value.toString().trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return null;
  }
}
