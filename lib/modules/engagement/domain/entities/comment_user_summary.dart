import '../../../profile/domain/entities/listener_visibility_mode.dart';

class CommentUserSummary {
  final String id;
  final String username;
  final String? avatarUrl;
  final ListenerVisibilityMode visibilityMode;

  const CommentUserSummary({
    required this.id,
    required this.username,
    required this.avatarUrl,
    this.visibilityMode = ListenerVisibilityMode.standard,
  });

  bool get isGhost => id.trim().isNotEmpty && visibilityMode.isGhost;
}
