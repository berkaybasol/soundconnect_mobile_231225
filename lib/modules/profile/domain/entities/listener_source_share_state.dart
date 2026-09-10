/// Server-confirmed publication identity shared by source draft composers.
/// Source-specific repositories retain their own routes and wire validation.
class ListenerSourceShareState {
  const ListenerSourceShareState({
    required this.sourceId,
    required this.shareId,
    required this.publishedOnProfile,
    required this.note,
    required this.publishedAt,
    required this.canPublish,
  });

  final String sourceId;
  final String? shareId;
  final bool publishedOnProfile;
  final String? note;
  final DateTime? publishedAt;
  final bool canPublish;
}
