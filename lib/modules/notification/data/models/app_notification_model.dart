import '../../domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.recipientId,
    required super.type,
    required super.title,
    required super.message,
    required super.read,
    required super.createdAt,
    required super.payload,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      recipientId: json['recipientId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Bildirim',
      message: json['message']?.toString() ?? '',
      read: json['read'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      payload: _payloadFromJson(json['payload']),
    );
  }

  static Map<String, dynamic> _payloadFromJson(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }
}
