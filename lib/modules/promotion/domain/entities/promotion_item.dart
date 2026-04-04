class PromotionItem {
  final String id;
  final String type;
  final String placement;
  final String status;
  final String title;
  final String? description;
  final String mediaAssetId;
  final String? mediaUrl;
  final String? redirectUrl;
  final int priority;

  const PromotionItem({
    required this.id,
    required this.type,
    required this.placement,
    required this.status,
    required this.title,
    required this.description,
    required this.mediaAssetId,
    required this.mediaUrl,
    required this.redirectUrl,
    required this.priority,
  });
}
