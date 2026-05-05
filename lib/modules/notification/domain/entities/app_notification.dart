class AppNotification {
  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;
  final Map<String, dynamic> payload;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    required this.payload,
  });

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      type: type,
      title: title,
      message: message,
      read: read ?? this.read,
      createdAt: createdAt,
      payload: payload,
    );
  }
}
