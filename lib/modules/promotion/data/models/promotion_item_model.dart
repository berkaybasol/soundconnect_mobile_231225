import '../../domain/entities/promotion_item.dart';

class PromotionItemModel extends PromotionItem {
  const PromotionItemModel({
    required super.id,
    required super.type,
    required super.placement,
    required super.status,
    required super.title,
    required super.description,
    required super.mediaAssetId,
    required super.mediaUrl,
    required super.redirectUrl,
    required super.priority,
  });

  factory PromotionItemModel.fromJson(Map<String, dynamic> json) {
    return PromotionItemModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      placement: json['placement']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      mediaAssetId: json['mediaAssetId']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      redirectUrl: json['redirectUrl']?.toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }
}
