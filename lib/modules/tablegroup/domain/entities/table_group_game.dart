import '../../../profile/domain/entities/listener_visibility_mode.dart';

enum TableGroupGameTopic { whoPays, unknown }

enum TableGroupGameMode { rockPaperScissors, dice, vote, unknown }

enum TableGroupGameStatus { lobby, inProgress, completed, cancelled, unknown }

enum TableGroupGamePhase {
  lobby,
  rockPaperScissors,
  dice,
  vote,
  voteTieDice,
  completed,
  cancelled,
  unknown,
}

enum TableGroupGamePlayerStatus { active, safe, timedOut, left, unknown }

enum TableGroupGameOutcome { assigned, volunteer, unknown }

enum TableGroupGameAction {
  rock('ROCK'),
  paper('PAPER'),
  scissors('SCISSORS'),
  roll('ROLL'),
  vote('VOTE'),
  volunteer('VOLUNTEER');

  const TableGroupGameAction(this.wireValue);

  final String wireValue;
}

class TableGroupGamePlayer {
  const TableGroupGamePlayer({
    required this.userId,
    required this.username,
    required this.status,
    required this.joinedAt,
    required this.hasActed,
    this.visibilityMode = ListenerVisibilityMode.standard,
  });

  final String userId;
  final String? username;
  final TableGroupGamePlayerStatus status;
  final DateTime? joinedAt;
  final bool hasActed;
  final ListenerVisibilityMode visibilityMode;

  bool get hasJoined =>
      status != TableGroupGamePlayerStatus.left &&
      status != TableGroupGamePlayerStatus.unknown;
  bool get canAct => status == TableGroupGamePlayerStatus.active;
  bool get isGhost => visibilityMode.isGhost;
}

class TableGroupGameRevealedAction {
  const TableGroupGameRevealedAction({
    required this.round,
    required this.phase,
    required this.actorUserId,
    required this.action,
    required this.targetUserId,
    required this.value,
  });

  final int round;
  final TableGroupGamePhase phase;
  final String actorUserId;
  final String action;
  final String? targetUserId;
  final int? value;
}

class TableGroupGame {
  const TableGroupGame({
    required this.schemaVersion,
    required this.gameId,
    required this.tableGroupId,
    required this.revision,
    required this.topic,
    required this.mode,
    required this.status,
    required this.phase,
    required this.createdBy,
    required this.createdByUsername,
    this.createdByVisibilityMode = ListenerVisibilityMode.standard,
    required this.round,
    required this.joinDeadlineAt,
    required this.actionDeadlineAt,
    required this.serverTime,
    required this.players,
    required this.revealedActions,
    required this.selectedUserId,
    required this.selectedUsername,
    this.selectedUserVisibilityMode = ListenerVisibilityMode.standard,
    required this.outcome,
    required this.resultMessage,
    required this.cancellationReason,
  });

  final int schemaVersion;
  final String gameId;
  final String tableGroupId;
  final int revision;
  final TableGroupGameTopic topic;
  final TableGroupGameMode mode;
  final TableGroupGameStatus status;
  final TableGroupGamePhase phase;
  final String createdBy;
  final String? createdByUsername;
  final ListenerVisibilityMode createdByVisibilityMode;
  final int round;
  final DateTime? joinDeadlineAt;
  final DateTime? actionDeadlineAt;
  final DateTime? serverTime;
  final List<TableGroupGamePlayer> players;
  final List<TableGroupGameRevealedAction> revealedActions;
  final String? selectedUserId;
  final String? selectedUsername;
  final ListenerVisibilityMode selectedUserVisibilityMode;
  final TableGroupGameOutcome? outcome;
  final String? resultMessage;
  final String? cancellationReason;

  bool get isTerminal =>
      status == TableGroupGameStatus.completed ||
      status == TableGroupGameStatus.cancelled;

  bool get isLobby =>
      status == TableGroupGameStatus.lobby ||
      phase == TableGroupGamePhase.lobby;

  bool get isCreatorGhost => createdByVisibilityMode.isGhost;
  // The contextual marker is authoritative. Keeping the badge visible even
  // for a malformed/partial terminal snapshot is the privacy-safe fallback.
  bool get isSelectedUserGhost => selectedUserVisibilityMode.isGhost;

  bool get supportsWhoPaysInteraction =>
      schemaVersion == 1 &&
      topic == TableGroupGameTopic.whoPays &&
      mode != TableGroupGameMode.unknown &&
      status != TableGroupGameStatus.unknown &&
      phase != TableGroupGamePhase.unknown &&
      _hasConsistentInteractivePhase;

  bool get _hasConsistentInteractivePhase {
    return switch (status) {
      TableGroupGameStatus.lobby => phase == TableGroupGamePhase.lobby,
      TableGroupGameStatus.inProgress => switch (mode) {
        TableGroupGameMode.rockPaperScissors =>
          phase == TableGroupGamePhase.rockPaperScissors,
        TableGroupGameMode.dice => phase == TableGroupGamePhase.dice,
        TableGroupGameMode.vote =>
          phase == TableGroupGamePhase.vote ||
              phase == TableGroupGamePhase.voteTieDice,
        TableGroupGameMode.unknown => false,
      },
      TableGroupGameStatus.completed => phase == TableGroupGamePhase.completed,
      TableGroupGameStatus.cancelled => phase == TableGroupGamePhase.cancelled,
      TableGroupGameStatus.unknown => false,
    };
  }

  DateTime? get phaseDeadline => isLobby ? joinDeadlineAt : actionDeadlineAt;

  TableGroupGamePlayer? playerFor(String? userId) {
    final normalized = userId?.trim() ?? '';
    if (normalized.isEmpty) return null;
    for (final player in players) {
      if (player.userId == normalized) return player;
    }
    return null;
  }
}
