import '../../domain/entities/table_group_game.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';
import 'table_group_wire_date.dart';

class TableGroupGameModel extends TableGroupGame {
  const TableGroupGameModel({
    required super.schemaVersion,
    required super.gameId,
    required super.tableGroupId,
    required super.revision,
    required super.topic,
    required super.mode,
    required super.status,
    required super.phase,
    required super.createdBy,
    required super.createdByUsername,
    super.createdByVisibilityMode,
    required super.round,
    required super.joinDeadlineAt,
    required super.actionDeadlineAt,
    required super.serverTime,
    required super.players,
    required super.revealedActions,
    required super.selectedUserId,
    required super.selectedUsername,
    super.selectedUserVisibilityMode,
    required super.outcome,
    required super.resultMessage,
    required super.cancellationReason,
  });

  factory TableGroupGameModel.fromWireJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty) {
        throw FormatException('Missing table-group game field: $key');
      }
      return value;
    }

    int requiredInt(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value.toInt() != value) {
        throw FormatException('Invalid table-group game field: $key');
      }
      return value.toInt();
    }

    final schemaVersion = requiredInt('schemaVersion');
    final revision = requiredInt('revision');
    final round = requiredInt('round');
    if (schemaVersion < 1 || revision < 1 || round < 0) {
      throw const FormatException('Invalid table-group game version');
    }

    return TableGroupGameModel(
      schemaVersion: schemaVersion,
      gameId: requiredText('gameId'),
      tableGroupId: requiredText('tableGroupId'),
      revision: revision,
      topic: _topic(requiredText('topic')),
      mode: _mode(requiredText('mode')),
      status: _status(requiredText('status')),
      phase: _phase(requiredText('phase')),
      createdBy: requiredText('createdBy'),
      createdByUsername: _optionalText(json['createdByUsername']),
      createdByVisibilityMode: parseContextualListenerVisibilityMode(
        json['createdByVisibilityMode'],
        rejectUnknown: true,
      ),
      round: round,
      joinDeadlineAt: _optionalDate(json, 'joinDeadlineAt'),
      actionDeadlineAt: _optionalDate(json, 'actionDeadlineAt'),
      serverTime: _optionalDate(json, 'serverTime'),
      players: _players(json['players']),
      revealedActions: _revealedActions(json['revealedActions']),
      selectedUserId: _optionalText(json['selectedUserId']),
      selectedUsername: _optionalText(json['selectedUsername']),
      selectedUserVisibilityMode: parseContextualListenerVisibilityMode(
        json['selectedUserVisibilityMode'],
        rejectUnknown: true,
      ),
      outcome: _outcome(json['outcome']),
      resultMessage: _optionalText(json['resultMessage']),
      cancellationReason: _optionalText(json['cancellationReason']),
    );
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _optionalDate(Map<String, dynamic> json, String key) {
    final raw = _optionalText(json[key]);
    if (raw == null) return null;
    final parsed = parseTableGroupWireDate(raw);
    if (parsed == null) {
      throw FormatException('Invalid table-group game date: $key');
    }
    return parsed;
  }

  static TableGroupGameMode _mode(String raw) {
    return switch (raw.trim().toUpperCase()) {
      'ROCK_PAPER_SCISSORS' => TableGroupGameMode.rockPaperScissors,
      'DICE' => TableGroupGameMode.dice,
      'VOTE' => TableGroupGameMode.vote,
      _ => TableGroupGameMode.unknown,
    };
  }

  static TableGroupGameTopic _topic(String raw) {
    return switch (raw.trim().toUpperCase()) {
      'WHO_PAYS' => TableGroupGameTopic.whoPays,
      _ => TableGroupGameTopic.unknown,
    };
  }

  static TableGroupGameStatus _status(String raw) {
    return switch (raw.trim().toUpperCase()) {
      'LOBBY' => TableGroupGameStatus.lobby,
      'IN_PROGRESS' => TableGroupGameStatus.inProgress,
      'COMPLETED' => TableGroupGameStatus.completed,
      'CANCELLED' => TableGroupGameStatus.cancelled,
      _ => TableGroupGameStatus.unknown,
    };
  }

  static TableGroupGamePhase _phase(String raw) {
    return switch (raw.trim().toUpperCase()) {
      'LOBBY' => TableGroupGamePhase.lobby,
      'RPS' => TableGroupGamePhase.rockPaperScissors,
      'DICE' => TableGroupGamePhase.dice,
      'VOTE' => TableGroupGamePhase.vote,
      'VOTE_TIE_DICE' => TableGroupGamePhase.voteTieDice,
      'COMPLETED' => TableGroupGamePhase.completed,
      'CANCELLED' => TableGroupGamePhase.cancelled,
      _ => TableGroupGamePhase.unknown,
    };
  }

  static TableGroupGamePlayerStatus _playerStatus(Object? raw) {
    return switch (raw?.toString().trim().toUpperCase()) {
      'ACTIVE' => TableGroupGamePlayerStatus.active,
      'SAFE' => TableGroupGamePlayerStatus.safe,
      'TIMED_OUT' => TableGroupGamePlayerStatus.timedOut,
      'LEFT' => TableGroupGamePlayerStatus.left,
      _ => TableGroupGamePlayerStatus.unknown,
    };
  }

  static TableGroupGameOutcome? _outcome(Object? raw) {
    final text = _optionalText(raw)?.toUpperCase();
    if (text == null) return null;
    return switch (text) {
      'ASSIGNED' => TableGroupGameOutcome.assigned,
      'VOLUNTEER' => TableGroupGameOutcome.volunteer,
      _ => TableGroupGameOutcome.unknown,
    };
  }

  static List<TableGroupGamePlayer> _players(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid table-group game players');
    }
    final seenUserIds = <String>{};
    return List<TableGroupGamePlayer>.unmodifiable(
      raw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid table-group game player');
        }
        final userId = _optionalText(item['userId']);
        final status = _optionalText(item['status']);
        final hasActed = item['hasActed'];
        if (userId == null || status == null || hasActed is! bool) {
          throw const FormatException('Missing table-group game player fields');
        }
        final joinedAtRaw = _optionalText(item['joinedAt']);
        final joinedAt = joinedAtRaw == null
            ? null
            : parseTableGroupWireDate(joinedAtRaw);
        if (joinedAtRaw != null && joinedAt == null) {
          throw const FormatException(
            'Invalid table-group game player joinedAt',
          );
        }
        if (!seenUserIds.add(userId)) {
          throw const FormatException('Duplicate table-group game player');
        }
        return TableGroupGamePlayer(
          userId: userId,
          username: _optionalText(item['username']),
          status: _playerStatus(status),
          joinedAt: joinedAt,
          hasActed: hasActed,
          visibilityMode: parseContextualListenerVisibilityMode(
            item['visibilityMode'],
            rejectUnknown: true,
          ),
        );
      }),
    );
  }

  static List<TableGroupGameRevealedAction> _revealedActions(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid table-group game reveals');
    }
    return List<TableGroupGameRevealedAction>.unmodifiable(
      raw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid table-group game reveal');
        }
        final actorUserId = _optionalText(item['actorUserId']);
        final action = _optionalText(item['action']);
        final phase = _optionalText(item['phase']);
        final rawRound = item['round'];
        if (actorUserId == null ||
            action == null ||
            phase == null ||
            rawRound is! num ||
            !rawRound.isFinite ||
            rawRound.toInt() != rawRound ||
            rawRound < 0) {
          throw const FormatException('Invalid table-group game reveal fields');
        }
        final rawValue = item['value'];
        if (rawValue != null &&
            (rawValue is! num ||
                !rawValue.isFinite ||
                rawValue.toInt() != rawValue)) {
          throw const FormatException('Invalid table-group game reveal value');
        }
        return TableGroupGameRevealedAction(
          round: rawRound.toInt(),
          phase: _phase(phase),
          actorUserId: actorUserId,
          action: action.toUpperCase(),
          targetUserId: _optionalText(item['targetUserId']),
          value: rawValue is num ? rawValue.toInt() : null,
        );
      }),
    );
  }
}
