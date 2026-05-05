import '../../domain/entities/overthinking_reveal_request.dart';

class OverthinkingRevealRequestModel extends OverthinkingRevealRequest {
  const OverthinkingRevealRequestModel({
    required super.id,
    required super.postId,
    required super.postTitle,
    required super.requesterId,
    required super.requesterUsername,
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
      authorId: json['authorId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
