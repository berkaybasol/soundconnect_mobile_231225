import 'table_group_game.dart';

class TableGroupMessage {
  final String messageId;
  final String tableGroupId;
  final String senderId;
  final String content;
  final String messageType;
  final DateTime? sentAt;
  final DateTime? deletedAt;
  final TableGroupGame? game;

  const TableGroupMessage({
    required this.messageId,
    required this.tableGroupId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.sentAt,
    required this.deletedAt,
    this.game,
  });
}
