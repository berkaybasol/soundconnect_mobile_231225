import '../../domain/entities/overthinking_reveal_request.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';

class OverthinkingRevealRequestModel extends OverthinkingRevealRequest {
  const OverthinkingRevealRequestModel({
    required super.id,
    required super.postId,
    required super.postTitle,
    required super.requesterId,
    required super.requesterUsername,
    super.requesterAvatarUrl,
    super.requesterVisibilityMode,
    required super.authorId,
    required super.status,
    required super.createdAt,
  });

  factory OverthinkingRevealRequestModel.fromJson(Map<String, dynamic> json) {
    return OverthinkingRevealRequestModel(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      postTitle: json['postTitle']?.toString() ?? '',
      requesterId: json['requesterId']?.toString() ?? '',
      requesterUsername: json['requesterUsername']?.toString() ?? '',
      requesterAvatarUrl: _nullableText(json['requesterAvatarUrl']),
      requesterVisibilityMode: parseContextualListenerVisibilityMode(
        json['requesterVisibilityMode'],
      ),
      authorId: json['authorId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
