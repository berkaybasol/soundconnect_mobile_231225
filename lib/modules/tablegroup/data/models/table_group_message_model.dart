import '../../domain/entities/table_group_message.dart';
import 'table_group_game_model.dart';
import 'table_group_wire_date.dart';

class TableGroupMessageModel extends TableGroupMessage {
  const TableGroupMessageModel({
    required super.messageId,
    required super.tableGroupId,
    required super.senderId,
    super.clientMessageId,
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
      clientMessageId: _optionalText(json['clientMessageId']),
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
      final value = json[key];
      if (value is! String || value.isEmpty || value != value.trim()) {
        throw FormatException('Missing table-group message field: $key');
      }
      return value;
    }

    final sentAtRaw = requiredText('sentAt');
    final sentAt = parseTableGroupWireDate(sentAtRaw);
    if (sentAt == null) {
      throw const FormatException('Invalid table-group message sentAt');
    }

    final deletedAtValue = json['deletedAt'];
    if (deletedAtValue != null && deletedAtValue is! String) {
      throw const FormatException('Invalid table-group message deletedAt');
    }
    final deletedAtRaw = deletedAtValue as String?;
    final deletedAt = deletedAtRaw == null || deletedAtRaw.isEmpty
        ? null
        : parseTableGroupWireDate(deletedAtRaw);
    if (deletedAtRaw != null && deletedAtRaw.isNotEmpty && deletedAt == null) {
      throw const FormatException('Invalid table-group message deletedAt');
    }

    final messageType = requiredText('messageType');
    if (!const <String>{
      'TEXT',
      'SYSTEM',
      'IMAGE',
      'GAME',
    }.contains(messageType)) {
      throw const FormatException('Invalid table-group message type');
    }
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

    final clientMessageId = _strictOptionalText(
      json['clientMessageId'],
      'clientMessageId',
    );
    if (messageType == 'TEXT' && clientMessageId == null) {
      throw const FormatException(
        'Missing table-group message field: clientMessageId',
      );
    }

    return TableGroupMessageModel(
      messageId: messageId,
      tableGroupId: tableGroupId,
      senderId: requiredText('senderId'),
      clientMessageId: clientMessageId,
      content: _requiredContent(json),
      messageType: messageType,
      sentAt: sentAt,
      deletedAt: deletedAt,
      game: game,
    );
  }

  static String _requiredContent(Map<String, dynamic> json) {
    final value = json['content'];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Missing table-group message field: content');
    }
    return value;
  }

  static String? _strictOptionalText(Object? raw, String key) {
    if (raw == null) return null;
    if (raw is! String || raw.isEmpty || raw != raw.trim()) {
      throw FormatException('Invalid table-group message field: $key');
    }
    return raw;
  }

  static String? _optionalText(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static TableGroupGameModel? _gameOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid table-group game payload');
    }
    return TableGroupGameModel.fromWireJson(raw);
  }
}
