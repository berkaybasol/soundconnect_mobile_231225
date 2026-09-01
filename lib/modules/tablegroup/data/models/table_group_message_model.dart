import '../../domain/entities/table_group_message.dart';
import 'table_group_game_model.dart';
import 'table_group_wire_date.dart';

class TableGroupMessageModel extends TableGroupMessage {
  const TableGroupMessageModel({
    required super.messageId,
    required super.tableGroupId,
    required super.senderId,
    required super.content,
    required super.messageType,
    required super.sentAt,
    required super.deletedAt,
    super.game,
  });

  factory TableGroupMessageModel.fromJson(Map<String, dynamic> json) {
    return TableGroupMessageModel(
      messageId: json['messageId']?.toString() ?? '',
      tableGroupId: json['tableGroupId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'TEXT',
      sentAt: parseTableGroupWireDate(json['sentAt']),
      deletedAt: parseTableGroupWireDate(json['deletedAt']),
      game: _gameOrNull(json['game']),
    );
  }

  /// Strict decoder for server-originated chat data.
  ///
  /// [fromJson] intentionally remains tolerant for legacy/local model use,
  /// while network boundaries must reject malformed identities instead of
  /// injecting unusable messages into the conversation.
  factory TableGroupMessageModel.fromWireJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty) {
        throw FormatException('Missing table-group message field: $key');
      }
      return value;
    }

    final sentAtRaw = requiredText('sentAt');
    final sentAt = parseTableGroupWireDate(sentAtRaw);
    if (sentAt == null) {
      throw const FormatException('Invalid table-group message sentAt');
    }

    final deletedAtRaw = json['deletedAt']?.toString().trim();
    final deletedAt = deletedAtRaw == null || deletedAtRaw.isEmpty
        ? null
        : parseTableGroupWireDate(deletedAtRaw);
    if (deletedAtRaw != null && deletedAtRaw.isNotEmpty && deletedAt == null) {
      throw const FormatException('Invalid table-group message deletedAt');
    }

    final messageType = requiredText('messageType').toUpperCase();
    final game = _gameOrNull(json['game']);
    if (messageType == 'GAME' && game == null) {
      throw const FormatException('Missing table-group game payload');
    }
    if (messageType != 'GAME' && game != null) {
      throw const FormatException(
        'Unexpected table-group game payload for non-game message',
      );
    }

    final messageId = requiredText('messageId');
    final tableGroupId = requiredText('tableGroupId');
    if (game != null && game.tableGroupId != tableGroupId) {
      throw const FormatException('Table-group game group mismatch');
    }

    return TableGroupMessageModel(
      messageId: messageId,
      tableGroupId: tableGroupId,
      senderId: requiredText('senderId'),
      content: _requiredContent(json),
      messageType: messageType,
      sentAt: sentAt,
      deletedAt: deletedAt,
      game: game,
    );
  }

  static String _requiredContent(Map<String, dynamic> json) {
    final value = json['content']?.toString();
    if (value == null || value.trim().isEmpty) {
      throw const FormatException('Missing table-group message field: content');
    }
    return value;
  }

  static TableGroupGameModel? _gameOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid table-group game payload');
    }
    return TableGroupGameModel.fromWireJson(raw);
  }
}
