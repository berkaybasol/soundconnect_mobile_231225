import '../../domain/entities/table_group_message.dart';

class TableGroupMessageModel extends TableGroupMessage {
  const TableGroupMessageModel({
    required super.messageId,
    required super.tableGroupId,
    required super.senderId,
    required super.content,
    required super.messageType,
    required super.sentAt,
    required super.deletedAt,
  });

  factory TableGroupMessageModel.fromJson(Map<String, dynamic> json) {
    return TableGroupMessageModel(
      messageId: json['messageId']?.toString() ?? '',
      tableGroupId: json['tableGroupId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'TEXT',
      sentAt: _toDate(json['sentAt']),
      deletedAt: _toDate(json['deletedAt']),
    );
  }

  static DateTime? _toDate(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
